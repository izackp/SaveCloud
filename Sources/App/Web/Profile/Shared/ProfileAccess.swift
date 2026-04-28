import Vapor
import HRW
import GRDB

struct ProfileGameSummary {
    let game: GameMeta
    let latestSave: Save

    var latestSaveDate: Date {
        latestSave.date ?? latestSave.updatedAt
    }
}

struct ProfileGameSaveSequenceGroup {
    let sequentialId: UUID
    let latestSave: Save
    let saves: [Save]

    var latestSaveDate: Date {
        latestSave.date ?? latestSave.updatedAt
    }
}

struct ProfileGameSaveVersionGroupData {
    let game: GameMeta
    let saves: [Save]
    let sequenceGroups: [ProfileGameSaveSequenceGroup]

    var latestSaveDate: Date {
        sequenceGroups.first?.latestSaveDate ?? .distantPast
    }
}

struct ProfileGameFamilySavesData {
    let familyId: UUID
    let displayGame: GameMeta
    let saves: [Save]
    let versionGroups: [ProfileGameSaveVersionGroupData]
}

struct ProfileSaveSequenceData {
    let sequentialId: UUID
    let displayGame: GameMeta
    let saves: [Save]
    let gamesById: [UUID: GameMeta]
}

enum ProfileGameSortField: String {
    case name
    case lastSaveDate = "last_save_date"
}

struct ProfileGamesPageState {
    let query: String
    let page: UInt
    let perPage: UInt
    let sortBy: ProfileGameSortField
    let sortAscending: Bool

    init(req: Request) {
        query = ((try? req.query.get(String.self, at: "q")) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        page = (try? req.query.get(UInt.self, at: "page")) ?? 0
        let requestedPerPage = (try? req.query.get(UInt.self, at: "per_page")) ?? 20
        perPage = min(max(requestedPerPage, 5), 100)
        let requestedSort = (try? req.query.get(String.self, at: "sort_by")) ?? ProfileGameSortField.lastSaveDate.rawValue
        sortBy = ProfileGameSortField(rawValue: requestedSort) ?? .lastSaveDate
        if let requestedAscending = try? req.query.get(Bool.self, at: "asc") {
            sortAscending = requestedAscending
        } else if let requestedAscending = try? req.query.get(String.self, at: "asc") {
            sortAscending = requestedAscending == "1" || requestedAscending.lowercased() == "true"
        } else {
            sortAscending = sortBy == .name
        }
    }

    func queryString(page: UInt? = nil, sortBy: ProfileGameSortField? = nil, asc: Bool? = nil) -> String {
        var items = [
            "page=\(page ?? self.page)",
            "per_page=\(perPage)",
            "sort_by=\((sortBy ?? self.sortBy).rawValue)",
            "asc=\((asc ?? sortAscending) ? "1" : "0")"
        ]
        var allowedCharacters = CharacterSet.urlQueryAllowed
        allowedCharacters.remove(charactersIn: "&=+")
        if !query.isEmpty,
           let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: allowedCharacters) {
            items.append("q=\(encodedQuery)")
        }
        return items.joined(separator: "&")
    }

    func sortQueryString(_ field: ProfileGameSortField) -> String {
        let nextAscending: Bool
        if sortBy == field {
            nextAscending = !sortAscending
        } else {
            nextAscending = field == .name
        }
        return queryString(page: 0, sortBy: field, asc: nextAscending)
    }
}

func shortProfileSaveDateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "M/d HH:mm"
    return formatter.string(from: date)
}

func fullProfileSaveDateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter.string(from: date)
}

func profileFileSizeText(_ byteCount: Int) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
}

func profileGameFamilyId(_ game: GameMeta) -> UUID {
    game.familyId ?? game.id
}

func profileGameVersionText(_ game: GameMeta) -> String {
    game.version.map { "Version \($0)" } ?? "No version recorded"
}

func isMoreRecent(_ lhs: Save, than rhs: Save) -> Bool {
    let lhsDate = lhs.date ?? lhs.updatedAt
    let rhsDate = rhs.date ?? rhs.updatedAt
    if lhsDate != rhsDate {
        return lhsDate > rhsDate
    }
    if lhs.updatedAt != rhs.updatedAt {
        return lhs.updatedAt > rhs.updatedAt
    }
    if lhs.createdAt != rhs.createdAt {
        return lhs.createdAt > rhs.createdAt
    }
    return lhs.id.uuidString > rhs.id.uuidString
}

func filterProfileGameSummaries(_ summaries: [ProfileGameSummary], state: ProfileGamesPageState) -> [ProfileGameSummary] {
    guard !state.query.isEmpty else {
        return summaries
    }
    return summaries.filter {
        $0.game.name.range(of: state.query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

func sortProfileGameSummaries(_ summaries: [ProfileGameSummary], state: ProfileGamesPageState) -> [ProfileGameSummary] {
    summaries.sorted { lhs, rhs in
        switch state.sortBy {
        case .name:
            let nameOrder = lhs.game.name.localizedCaseInsensitiveCompare(rhs.game.name)
            if nameOrder != .orderedSame {
                return state.sortAscending ? nameOrder == .orderedAscending : nameOrder == .orderedDescending
            }
            if lhs.latestSaveDate != rhs.latestSaveDate {
                return lhs.latestSaveDate > rhs.latestSaveDate
            }
        case .lastSaveDate:
            if lhs.latestSaveDate != rhs.latestSaveDate {
                return state.sortAscending ? lhs.latestSaveDate < rhs.latestSaveDate : lhs.latestSaveDate > rhs.latestSaveDate
            }
            let nameOrder = lhs.game.name.localizedCaseInsensitiveCompare(rhs.game.name)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }
        }
        return lhs.game.id.uuidString < rhs.game.id.uuidString
    }
}

func pageProfileGameSummaries(_ summaries: [ProfileGameSummary], state: ProfileGamesPageState) -> ([ProfileGameSummary], Bool) {
    let startIndex = Int(state.page * state.perPage)
    guard startIndex < summaries.count else {
        return ([], false)
    }
    let endIndex = min(startIndex + Int(state.perPage), summaries.count)
    return (Array(summaries[startIndex..<endIndex]), endIndex < summaries.count)
}

struct ProfileNavigationContext {
    let rootLabel: String
    let rootLinkPath: String
    let backLinkPath: String
    let basePath: String
    let savesBasePath: String
    let sequenceBasePath: String

    func familyPath(_ familyId: UUID) -> String {
        "\(basePath)/games-family/\(familyId.uuidString)"
    }
}

func profileNavigationContext(session: AuthSession, profile: UserProfile) -> ProfileNavigationContext {
    let basePath = "/profile/\(profile.id.description)"
    if session.isAdmin && profile.userId != session.user {
        let rootLinkPath = "/users/\(profile.userId.description)"
        return ProfileNavigationContext(
            rootLabel: "User",
            rootLinkPath: rootLinkPath,
            backLinkPath: rootLinkPath,
            basePath: basePath,
            savesBasePath: "\(basePath)/saves",
            sequenceBasePath: "\(basePath)/saves-sequence"
        )
    }
    return ProfileNavigationContext(
        rootLabel: "Profiles",
        rootLinkPath: "/user/profiles",
        backLinkPath: "/user/profiles",
        basePath: basePath,
        savesBasePath: "\(basePath)/saves",
        sequenceBasePath: "\(basePath)/saves-sequence"
    )
}

func profileNotFoundResponse(session: AuthSession, req: Request, pool: DatabasePool, error: String) async throws -> Response {
    if session.isAdmin {
        return try VCEditAllUsersPage(session: session, users: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: error).rootNode.response()
    }
    let profiles = try await fetchUserProfiles(for: session, pool: pool)
    return try VCUserProfilesPage(session: session, profiles: profiles, error: error).rootNode.response()
}

func fetchAccessibleProfile(req: Request, session: AuthSession, pool: DatabasePool) async throws -> UserProfile? {
    guard let profileId: SmallUid = req.parameters.get("profile_id") else {
        return nil
    }
    let profile = try await pool.read { db in
        try UserProfile.filter(id: profileId).fetchOne(db)
    }
    guard let profile else {
        return nil
    }
    guard session.isAdmin || profile.userId == session.user else {
        return nil
    }
    return profile
}

func fetchProfileGameSummaries(userId: SmallUid, profile: UserProfile, pool: DatabasePool) async throws -> [ProfileGameSummary] {
    try await pool.read { db in
        let saves = try Save
            .filter(Save.user_id == userId)
            .filter(Save.profile_id == profile.id)
            .filter(Save.game_meta_id != nil)
            .fetchAll(db)

        var latestSaveByGameId = [UUID: Save]()
        for save in saves {
            guard let gameMetaId = save.gameMetaId else {
                continue
            }
            guard let existing = latestSaveByGameId[gameMetaId] else {
                latestSaveByGameId[gameMetaId] = save
                continue
            }
            if isMoreRecent(save, than: existing) {
                latestSaveByGameId[gameMetaId] = save
            }
        }

        let gameIds = Array(latestSaveByGameId.keys)
        guard !gameIds.isEmpty else {
            return []
        }

        let games = try GameMeta
            .filter(gameIds.contains(GameMeta.id))
            .fetchAll(db)
        let gamesById = Dictionary(uniqueKeysWithValues: games.map { ($0.id, $0) })

        return latestSaveByGameId.compactMap { gameId, latestSave in
            guard let game = gamesById[gameId] else {
                return nil
            }
            return ProfileGameSummary(game: game, latestSave: latestSave)
        }
        .sorted { lhs, rhs in
            let lhsDate = lhs.latestSaveDate
            let rhsDate = rhs.latestSaveDate
            if lhsDate != rhsDate {
                return lhsDate > rhsDate
            }
            if lhs.game.name != rhs.game.name {
                return lhs.game.name.localizedCaseInsensitiveCompare(rhs.game.name) == .orderedAscending
            }
            return lhs.game.id.uuidString < rhs.game.id.uuidString
        }
    }
}

func fetchProfileSave(userId: SmallUid, profile: UserProfile, saveId: UUID, pool: DatabasePool) async throws -> Save? {
    try await pool.read { db in
        try Save
            .filter(id: saveId)
            .filter(Save.user_id == userId)
            .filter(Save.profile_id == profile.id)
            .fetchOne(db)
    }
}

func buildProfileGameFamilySavesData(familyId: UUID, games: [GameMeta], saves: [Save]) -> ProfileGameFamilySavesData? {
    guard !games.isEmpty else {
        return nil
    }
    let gamesById = Dictionary(uniqueKeysWithValues: games.map { ($0.id, $0) })
    let displayGame = games.sorted { lhs, rhs in
        let lhsSaves = saves.filter { $0.gameMetaId == lhs.id }
        let rhsSaves = saves.filter { $0.gameMetaId == rhs.id }
        guard let lhsLatest = lhsSaves.sorted(by: isMoreRecent(_:than:)).first else {
            return false
        }
        guard let rhsLatest = rhsSaves.sorted(by: isMoreRecent(_:than:)).first else {
            return true
        }
        return isMoreRecent(lhsLatest, than: rhsLatest)
    }.first ?? games[0]

    let savesByGameId = Dictionary(grouping: saves) { $0.gameMetaId }
    let versionGroups = savesByGameId.compactMap { gameId, gameSaves -> ProfileGameSaveVersionGroupData? in
        guard let gameId, let game = gamesById[gameId] else {
            return nil
        }
        let sequenceGroups = Dictionary(grouping: gameSaves) { $0.sequentialId }
            .map { sequentialId, sequenceSaves in
                let sortedSaves = sequenceSaves.sorted(by: isMoreRecent(_:than:))
                return ProfileGameSaveSequenceGroup(sequentialId: sequentialId, latestSave: sortedSaves[0], saves: sortedSaves)
            }
            .sorted { lhs, rhs in
                if lhs.latestSaveDate != rhs.latestSaveDate {
                    return lhs.latestSaveDate > rhs.latestSaveDate
                }
                return lhs.sequentialId.uuidString < rhs.sequentialId.uuidString
            }
        let sortedGameSaves = gameSaves.sorted(by: isMoreRecent(_:than:))
        return ProfileGameSaveVersionGroupData(game: game, saves: sortedGameSaves, sequenceGroups: sequenceGroups)
    }
    .sorted { lhs, rhs in
        if lhs.latestSaveDate != rhs.latestSaveDate {
            return lhs.latestSaveDate > rhs.latestSaveDate
        }
        return profileGameVersionText(lhs.game) < profileGameVersionText(rhs.game)
    }

    return ProfileGameFamilySavesData(familyId: familyId, displayGame: displayGame, saves: saves.sorted(by: isMoreRecent(_:than:)), versionGroups: versionGroups)
}

func fetchProfileGameFamily(userId: SmallUid, profile: UserProfile, familyId: UUID, pool: DatabasePool) async throws -> ProfileGameFamilySavesData? {
    try await pool.read { db in
        let games = try GameMeta
            .filter(GameMeta.id == familyId || GameMeta.family_id == familyId)
            .fetchAll(db)
        let gameIds = games.map(\.id)
        guard !gameIds.isEmpty else {
            return nil
        }
        let saves = try Save
            .filter(Save.user_id == userId)
            .filter(Save.profile_id == profile.id)
            .filter(gameIds.contains(Save.game_meta_id))
            .fetchAll(db)
        return buildProfileGameFamilySavesData(familyId: familyId, games: games, saves: saves)
    }
}

func fetchProfileSaveSequence(userId: SmallUid, profile: UserProfile, sequenceId: UUID, pool: DatabasePool) async throws -> ProfileSaveSequenceData? {
    try await pool.read { db in
        let saves = try Save
            .filter(Save.user_id == userId)
            .filter(Save.profile_id == profile.id)
            .filter(Save.sequential_id == sequenceId)
            .fetchAll(db)
            .sorted(by: isMoreRecent(_:than:))
        guard !saves.isEmpty else {
            return nil
        }
        let gameIds = Array(Set(saves.compactMap(\.gameMetaId)))
        let games = try GameMeta
            .filter(gameIds.contains(GameMeta.id))
            .fetchAll(db)
        let gamesById = Dictionary(uniqueKeysWithValues: games.map { ($0.id, $0) })
        guard let displayGame = saves.compactMap({ save in
            save.gameMetaId.flatMap { gamesById[$0] }
        }).first ?? games.first else {
            return nil
        }
        return ProfileSaveSequenceData(sequentialId: sequenceId, displayGame: displayGame, saves: saves, gamesById: gamesById)
    }
}

func findSequenceGroup(_ sequentialId: UUID, in familyData: ProfileGameFamilySavesData) -> ProfileGameSaveSequenceGroup? {
    familyData.versionGroups
        .flatMap(\.sequenceGroups)
        .first { $0.sequentialId == sequentialId }
}

func deleteProfileGameFamilySaves(userId: SmallUid, profile: UserProfile, familyId: UUID, sequentialId: UUID?, pool: DatabasePool) async throws {
    try await pool.write { db in
        let games = try GameMeta
            .filter(GameMeta.id == familyId || GameMeta.family_id == familyId)
            .fetchAll(db)
        let gameIds = games.map(\.id)
        var request = Save
            .filter(Save.user_id == userId)
            .filter(Save.profile_id == profile.id)
            .filter(gameIds.contains(Save.game_meta_id))
        if let sequentialId {
            request = request.filter(Save.sequential_id == sequentialId)
        }
        _ = try request.deleteAll(db)
    }
}

func deleteProfileSave(userId: SmallUid, profile: UserProfile, saveId: UUID, pool: DatabasePool) async throws {
    try await pool.write { db in
        _ = try Save
            .filter(id: saveId)
            .filter(Save.user_id == userId)
            .filter(Save.profile_id == profile.id)
            .deleteAll(db)
    }
}
