import Vapor
import HRW
import GRDB

private struct UserProfileCreateRequest: Content {
    let id: String?
    let name: String

    var trimmedId: String? {
        guard let id else { return nil }
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func validate() -> String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Name is empty."
        }
        if let trimmedId, SmallUid(trimmedId) == nil {
            return "Profile ID is invalid."
        }
        return nil
    }
}

final class VCProfileGridItem: ProfileGridItem {
    init(profile: UserProfile) throws {
        try super.init()
        profile_link.href = URL(string: "/user/profile/\(profile.id.description)/games")
        let profileId = profile.id.description
        profile_avatar_container.addChild(HTMLText(content: #"<svg width="80" height="80" data-jdenticon-value="\#(profileId)"></svg>"#))
        name.addChild(HTMLText(content: profile.name))
    }
}

final class VCUserProfilesPage: UserProfilesPage {
    init(session: AuthSession, profiles: [UserProfile], error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        if let error {
            p_error.addChild(HTMLText(content: error))
            p_error.globalAttributes[.style] = ""
        }
        for profile in profiles {
            profiles_container.children.append(try VCProfileGridItem(profile: profile).rootNode)
        }
    }
}

final class VCProfileDetailPage: ProfileDetailPage {
    init(session: AuthSession, profile: UserProfile, error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        if let error {
            p_error.addChild(HTMLText(content: error))
            p_error.globalAttributes[.style] = ""
        }
        title.addChild(HTMLText(content: profile.name))
        let profileId = profile.id.description
        profile_avatar_container.addChild(HTMLText(content: #"<svg width="120" height="120" data-jdenticon-value="\#(profileId)"></svg>"#))
        profile_id.addChild(HTMLText(content: profile.id.description))
        name.addChild(HTMLText(content: profile.name))
        profile_id_record.addChild(HTMLText(content: profile.id.description))
        back_link.href = URL(string: "/user/profiles")
    }
}

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

private func shortProfileSaveDateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "M/d HH:mm"
    return formatter.string(from: date)
}

private func fullProfileSaveDateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter.string(from: date)
}

private func profileFileSizeText(_ byteCount: Int) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
}

private func profileGameFamilyId(_ game: GameMeta) -> UUID {
    game.familyId ?? game.id
}

private func profileGameVersionText(_ game: GameMeta) -> String {
    game.version.map { "Version \($0)" } ?? "No version recorded"
}

private func isMoreRecent(_ lhs: Save, than rhs: Save) -> Bool {
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

private func filterProfileGameSummaries(_ summaries: [ProfileGameSummary], state: ProfileGamesPageState) -> [ProfileGameSummary] {
    guard !state.query.isEmpty else {
        return summaries
    }
    return summaries.filter {
        $0.game.name.range(of: state.query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

private func sortProfileGameSummaries(_ summaries: [ProfileGameSummary], state: ProfileGamesPageState) -> [ProfileGameSummary] {
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

private func pageProfileGameSummaries(_ summaries: [ProfileGameSummary], state: ProfileGamesPageState) -> ([ProfileGameSummary], Bool) {
    let startIndex = Int(state.page * state.perPage)
    guard startIndex < summaries.count else {
        return ([], false)
    }
    let endIndex = min(startIndex + Int(state.perPage), summaries.count)
    return (Array(summaries[startIndex..<endIndex]), endIndex < summaries.count)
}

final class VCProfileGamesTableRow: ProfileGamesTableRow {
    init(summary: ProfileGameSummary, href: String) throws {
        try super.init()
        game_link.href = URL(string: href)
        game_name.addChild(HTMLText(content: summary.game.name))
        version.addChild(HTMLText(content: summary.game.version.map { "Version \($0)" } ?? "No version"))
        let latestDate = summary.latestSaveDate
        latest_save_date.addChild(HTMLText(content: shortProfileSaveDateText(latestDate)))
        latest_save_date.globalAttributes[.title] = fullProfileSaveDateText(latestDate)
        save_name.addChild(HTMLText(content: summary.latestSave.name ?? "Untitled save"))
    }
}

final class VCProfileGamesPage: ProfileGamesPage {
    init(session: AuthSession, profile: UserProfile, summaries: [ProfileGameSummary], totalCount: Int, state: ProfileGamesPageState, hasNextPage: Bool, listPath: String, gameLinkBasePath: String, backLinkPath: String, error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        if let error {
            p_error.addChild(HTMLText(content: error))
            p_error.globalAttributes[.style] = ""
        }
        title.addChild(HTMLText(content: profile.name))
        let profileId = profile.id.description
        profile_avatar_container.addChild(HTMLText(content: #"<svg width="120" height="120" data-jdenticon-value="\#(profileId)"></svg>"#))
        profile_id.addChild(HTMLText(content: profile.name))
        let summaryCopy = totalCount == 1 ? "1 game" : "\(totalCount) games"
        summary_text.addChild(HTMLText(content: summaryCopy))
        search_input.value = state.query
        sort_by_input.value = state.sortBy.rawValue
        asc_input.value = state.sortAscending ? "1" : "0"
        sort_name_link.href = URL(string: "\(listPath)?\(state.sortQueryString(.name))")
        sort_date_link.href = URL(string: "\(listPath)?\(state.sortQueryString(.lastSaveDate))")
        if state.sortBy == .name {
            sort_name_link.globalAttributes[.class_] = "profile-game-sort-button is-active"
        } else {
            sort_date_link.globalAttributes[.class_] = "profile-game-sort-button is-active"
        }
        let startCount = summaries.isEmpty ? 0 : Int(state.page * state.perPage) + 1
        let endCount = Int(state.page * state.perPage) + summaries.count
        let resultCopy = state.query.isEmpty
            ? "Showing \(startCount)-\(endCount) of \(totalCount)"
            : "Showing \(startCount)-\(endCount) of \(totalCount) matches"
        result_count.addChild(HTMLText(content: resultCopy))
        if summaries.isEmpty {
            empty_text.globalAttributes[.style] = ""
        } else {
            for summary in summaries {
                let href = "\(gameLinkBasePath)/\(profileGameFamilyId(summary.game).uuidString)"
                game_list.children.append(try VCProfileGamesTableRow(summary: summary, href: href).rootNode)
            }
        }
        page_text.addChild(HTMLText(content: "Page \(state.page + 1)"))
        if state.page > 0 {
            prev_link.href = URL(string: "\(listPath)?\(state.queryString(page: state.page - 1))")
            prev_link.globalAttributes[.style] = ""
        }
        if hasNextPage {
            next_link.href = URL(string: "\(listPath)?\(state.queryString(page: state.page + 1))")
            next_link.globalAttributes[.style] = ""
        }
        back_link.href = URL(string: backLinkPath)
    }
}

final class VCProfileGameSaveRow: ProfileGameSaveRow {
    init(group: ProfileGameSaveSequenceGroup, downloadPath: String, deletePath: String, sequencePath: String) throws {
        try super.init()
        let save = group.latestSave
        save_name.addChild(HTMLText(content: save.name ?? "Untitled save"))
        save_count.addChild(HTMLText(content: group.saves.count == 1 ? "1 save in sequence" : "\(group.saves.count) saves in sequence"))
        sequence_link.href = URL(string: sequencePath)
        source_device.addChild(HTMLText(content: save.sourceDevice ?? "Unknown device"))
        file_size.addChild(HTMLText(content: profileFileSizeText(save.fileSize)))
        let saveDate = save.date ?? save.updatedAt
        save_date.addChild(HTMLText(content: fullProfileSaveDateText(saveDate)))
        download_link.href = URL(string: downloadPath)
        delete_link.href = URL(string: deletePath)
    }
}

final class VCProfileGameSaveVersionGroup: ProfileGameSaveVersionGroup {
    init(versionGroup: ProfileGameSaveVersionGroupData, saveBasePath: String, deleteSequenceBasePath: String, sequenceBasePath: String) throws {
        try super.init()
        version_title.addChild(HTMLText(content: profileGameVersionText(versionGroup.game)))
        let sequenceCopy = versionGroup.sequenceGroups.count == 1 ? "1 save sequence" : "\(versionGroup.sequenceGroups.count) save sequences"
        let saveCopy = versionGroup.saves.count == 1 ? "1 save" : "\(versionGroup.saves.count) saves"
        version_summary.addChild(HTMLText(content: "\(sequenceCopy), \(saveCopy)"))
        version_game_link.href = URL(string: "/games/\(versionGroup.game.id.uuidString)")
        for group in versionGroup.sequenceGroups {
            saves_list.children.append(try VCProfileGameSaveRow(
                group: group,
                downloadPath: "\(saveBasePath)/\(group.latestSave.id.uuidString)",
                deletePath: "\(deleteSequenceBasePath)/\(group.sequentialId.uuidString)/delete",
                sequencePath: "\(sequenceBasePath)/\(group.sequentialId.uuidString)"
            ).rootNode)
        }
    }
}

final class VCProfileGameSaveDownloadRow: ProfileGameSaveDownloadRow {
    init(save: Save, downloadPath: String) throws {
        try super.init()
        save_name.addChild(HTMLText(content: save.name ?? "Untitled save"))
        let saveDate = save.date ?? save.updatedAt
        save_date.addChild(HTMLText(content: fullProfileSaveDateText(saveDate)))
        download_link.href = URL(string: downloadPath)
    }
}

final class VCProfileGameSavesPage: ProfileGameSavesPage {
    init(session: AuthSession, profile: UserProfile, familyData: ProfileGameFamilySavesData, rootLabel: String, rootLinkPath: String, backLinkPath: String, downloadAllPath: String, deleteAllPath: String, saveBasePath: String, deleteSequenceBasePath: String, sequenceBasePath: String, error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        if let error {
            p_error.addChild(HTMLText(content: error))
            p_error.globalAttributes[.style] = ""
        }
        breadcrumb_root_label.addChild(HTMLText(content: rootLabel))
        breadcrumb_root_link.href = URL(string: rootLinkPath)
        breadcrumb_profile_link.href = URL(string: backLinkPath)
        breadcrumb_profile_name.addChild(HTMLText(content: profile.name))
        breadcrumb_game_name.addChild(HTMLText(content: familyData.displayGame.name))
        let summaryCopy = familyData.saves.count == 1 ? "1 save" : "\(familyData.saves.count) saves"
        summary_text.addChild(HTMLText(content: summaryCopy))
        game_name.addChild(HTMLText(content: familyData.displayGame.name))
        game_detail_link.href = URL(string: "/games/\(familyData.displayGame.id.uuidString)")
        download_all_link.href = URL(string: downloadAllPath)
        delete_all_link.href = URL(string: deleteAllPath)
        if familyData.saves.isEmpty {
            empty_text.globalAttributes[.style] = ""
        } else {
            for versionGroup in familyData.versionGroups {
                version_groups.children.append(try VCProfileGameSaveVersionGroup(
                    versionGroup: versionGroup,
                    saveBasePath: saveBasePath,
                    deleteSequenceBasePath: deleteSequenceBasePath,
                    sequenceBasePath: sequenceBasePath
                ).rootNode)
            }
        }
        back_link.href = URL(string: backLinkPath)
    }
}

final class VCProfileGameSavesDownloadPage: ProfileGameSavesDownloadPage {
    init(session: AuthSession, familyData: ProfileGameFamilySavesData, saveBasePath: String, backLinkPath: String) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        title.addChild(HTMLText(content: "Download \(familyData.displayGame.name) latest saves"))
        let latestSaves = familyData.versionGroups.flatMap { $0.sequenceGroups.map(\.latestSave) }
        let summaryCopy = latestSaves.count == 1 ? "1 latest save available" : "\(latestSaves.count) latest saves available"
        summary_text.addChild(HTMLText(content: summaryCopy))
        for save in latestSaves.sorted(by: isMoreRecent(_:than:)) {
            download_list.children.append(try VCProfileGameSaveDownloadRow(save: save, downloadPath: "\(saveBasePath)/\(save.id.uuidString)").rootNode)
        }
        back_link.href = URL(string: backLinkPath)
    }
}

final class VCDeleteProfileGameSavesPage: DeleteProfileGameSavesPage {
    init(session: AuthSession, profile: UserProfile, familyData: ProfileGameFamilySavesData, deletePath: String, cancelPath: String, sequenceGroup: ProfileGameSaveSequenceGroup?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        let isSequenceDelete = sequenceGroup != nil
        title.addChild(HTMLText(content: isSequenceDelete ? "Delete Save Sequence" : "Delete All Saves"))
        message.addChild(HTMLText(content: isSequenceDelete ? "This will permanently delete every save in this sequence." : "This will permanently delete every save for this game family in this profile."))
        game_name.addChild(HTMLText(content: familyData.displayGame.name))
        profile_name.addChild(HTMLText(content: profile.name))
        if let sequenceGroup {
            let copy = sequenceGroup.saves.count == 1 ? "1 save" : "\(sequenceGroup.saves.count) saves"
            save_count.addChild(HTMLText(content: copy))
        } else {
            save_count.addChild(HTMLText(content: familyData.saves.count == 1 ? "1 save" : "\(familyData.saves.count) saves"))
        }
        delete_form.action = URL(string: deletePath)
        delete_button.addChild(HTMLText(content: isSequenceDelete ? "Delete Sequence" : "Delete All Saves"))
        cancel_link.href = URL(string: cancelPath)
    }
}

final class VCProfileSequenceSaveRow: ProfileSequenceSaveRow {
    init(save: Save, game: GameMeta?, downloadPath: String, deletePath: String) throws {
        try super.init()
        save_name.addChild(HTMLText(content: save.name ?? "Untitled save"))
        let saveDate = save.date ?? save.updatedAt
        save_date.addChild(HTMLText(content: fullProfileSaveDateText(saveDate)))
        version_text.addChild(HTMLText(content: game.map { profileGameVersionText($0) } ?? "No version recorded"))
        source_device.addChild(HTMLText(content: save.sourceDevice ?? "Unknown device"))
        file_size.addChild(HTMLText(content: profileFileSizeText(save.fileSize)))
        download_link.href = URL(string: downloadPath)
        delete_link.href = URL(string: deletePath)
    }
}

final class VCProfileSaveSequencePage: ProfileSaveSequencePage {
    init(session: AuthSession, profile: UserProfile, sequenceData: ProfileSaveSequenceData, rootLabel: String, rootLinkPath: String, profileLinkPath: String, gameLinkPath: String, backLinkPath: String, saveBasePath: String, error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        if let error {
            p_error.addChild(HTMLText(content: error))
            p_error.globalAttributes[.style] = ""
        }
        breadcrumb_root_label.addChild(HTMLText(content: rootLabel))
        breadcrumb_root_link.href = URL(string: rootLinkPath)
        breadcrumb_profile_name.addChild(HTMLText(content: profile.name))
        breadcrumb_profile_link.href = URL(string: profileLinkPath)
        breadcrumb_game_name.addChild(HTMLText(content: sequenceData.displayGame.name))
        breadcrumb_game_link.href = URL(string: gameLinkPath)
        let saveCopy = sequenceData.saves.count == 1 ? "1 save in sequence" : "\(sequenceData.saves.count) saves in sequence"
        title.addChild(HTMLText(content: saveCopy))
        summary_text.addChild(HTMLText(content: "Ordered by newest save first"))
        if sequenceData.saves.isEmpty {
            empty_text.globalAttributes[.style] = ""
        } else {
            for save in sequenceData.saves {
                let game = save.gameMetaId.flatMap { sequenceData.gamesById[$0] }
                saves_list.children.append(try VCProfileSequenceSaveRow(
                    save: save,
                    game: game,
                    downloadPath: "\(saveBasePath)/\(save.id.uuidString)",
                    deletePath: "\(saveBasePath)/\(save.id.uuidString)/delete"
                ).rootNode)
            }
        }
        back_link.href = URL(string: backLinkPath)
    }
}

final class VCDeleteProfileSavePage: DeleteProfileSavePage {
    init(session: AuthSession, profile: UserProfile, game: GameMeta?, save: Save, deletePath: String, cancelPath: String) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        title.addChild(HTMLText(content: "Delete Save"))
        message.addChild(HTMLText(content: "This will permanently delete this save."))
        game_name.addChild(HTMLText(content: game?.name ?? "Unknown game"))
        profile_name.addChild(HTMLText(content: profile.name))
        save_name.addChild(HTMLText(content: save.name ?? "Untitled save"))
        let saveDate = save.date ?? save.updatedAt
        save_date.addChild(HTMLText(content: fullProfileSaveDateText(saveDate)))
        delete_form.action = URL(string: deletePath)
        delete_button.addChild(HTMLText(content: "Delete Save"))
        cancel_link.href = URL(string: cancelPath)
    }
}

private func fetchUserProfiles(for session: AuthSession, pool: DatabasePool) async throws -> [UserProfile] {
    try await pool.read { db in
        try UserProfile
            .filter(UserProfile.user_id == session.user)
            .order(UserProfile.name.asc)
            .fetchAll(db)
    }
}

private func fetchOwnedProfile(req: Request, session: AuthSession, pool: DatabasePool) async throws -> UserProfile? {
    guard let profileId: SmallUid = req.parameters.get("profile_id") else {
        return nil
    }
    return try await pool.read { db in
        try UserProfile
            .filter(id: profileId)
            .filter(UserProfile.user_id == session.user)
            .fetchOne(db)
    }
}

private func fetchProfile(userId: SmallUid, profileId: SmallUid, pool: DatabasePool) async throws -> UserProfile? {
    try await pool.read { db in
        try UserProfile
            .filter(id: profileId)
            .filter(UserProfile.user_id == userId)
            .fetchOne(db)
    }
}

private func fetchProfileGameSummaries(userId: SmallUid, profile: UserProfile, pool: DatabasePool) async throws -> [ProfileGameSummary] {
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

private func fetchProfileGame(userId: SmallUid, profile: UserProfile, gameId: UUID, pool: DatabasePool) async throws -> (GameMeta, [Save])? {
    try await pool.read { db in
        guard let game = try GameMeta.filter(id: gameId).fetchOne(db) else {
            return nil
        }
        let saves = try Save
            .filter(Save.user_id == userId)
            .filter(Save.profile_id == profile.id)
            .filter(Save.game_meta_id == gameId)
            .fetchAll(db)
            .sorted { lhs, rhs in
                if isMoreRecent(lhs, than: rhs) {
                    return true
                }
                if isMoreRecent(rhs, than: lhs) {
                    return false
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        return (game, saves)
    }
}

private func fetchProfileSave(userId: SmallUid, profile: UserProfile, saveId: UUID, pool: DatabasePool) async throws -> Save? {
    try await pool.read { db in
        try Save
            .filter(id: saveId)
            .filter(Save.user_id == userId)
            .filter(Save.profile_id == profile.id)
            .fetchOne(db)
    }
}

private func buildProfileGameFamilySavesData(familyId: UUID, games: [GameMeta], saves: [Save]) -> ProfileGameFamilySavesData? {
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

private func fetchProfileGameFamily(userId: SmallUid, profile: UserProfile, familyId: UUID, pool: DatabasePool) async throws -> ProfileGameFamilySavesData? {
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

private func fetchProfileSaveSequence(userId: SmallUid, profile: UserProfile, sequenceId: UUID, pool: DatabasePool) async throws -> ProfileSaveSequenceData? {
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

private func findSequenceGroup(_ sequentialId: UUID, in familyData: ProfileGameFamilySavesData) -> ProfileGameSaveSequenceGroup? {
    familyData.versionGroups
        .flatMap(\.sequenceGroups)
        .first { $0.sequentialId == sequentialId }
}

private func fetchProfileGameSave(userId: SmallUid, profile: UserProfile, gameId: UUID, saveId: UUID, pool: DatabasePool) async throws -> Save? {
    try await pool.read { db in
        try Save
            .filter(id: saveId)
            .filter(Save.user_id == userId)
            .filter(Save.profile_id == profile.id)
            .filter(Save.game_meta_id == gameId)
            .fetchOne(db)
    }
}

private func deleteProfileGameFamilySaves(userId: SmallUid, profile: UserProfile, familyId: UUID, sequentialId: UUID?, pool: DatabasePool) async throws {
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

private func deleteProfileSave(userId: SmallUid, profile: UserProfile, saveId: UUID, pool: DatabasePool) async throws {
    try await pool.write { db in
        _ = try Save
            .filter(id: saveId)
            .filter(Save.user_id == userId)
            .filter(Save.profile_id == profile.id)
            .deleteAll(db)
    }
}

@Sendable func userProfilesPage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try expiredSessionResponse()
    }
    let pool = DBShared.pool()
    let profiles = try await fetchUserProfiles(for: session, pool: pool)
    return try VCUserProfilesPage(session: session, profiles: profiles, error: nil).rootNode.response()
}

@Sendable func createUserProfile(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try expiredSessionResponse()
    }
    let contents = try req.content.decode(UserProfileCreateRequest.self)
    if let error = contents.validate() {
        let profiles = try await fetchUserProfiles(for: session, pool: DBShared.pool())
        return try VCUserProfilesPage(session: session, profiles: profiles, error: error).rootNode.response()
    }

    let profileId = if let trimmedId = contents.trimmedId {
        try SmallUid(base64URL: trimmedId)
    } else {
        SmallUid.generate()
    }
    let trimmedName = contents.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let date = Date()
    let pool = DBShared.pool()

    do {
        let profile = try await pool.write { db in
            var profile = UserProfile(id: profileId, userId: session.user, name: trimmedName, createdAt: date, updatedAt: date)
            try profile.insert(db)
            return profile
        }
        return req.redirect(to: "/user/profile/\(profile.id.description)/games", redirectType: .normal)
    } catch {
        let profiles = try await fetchUserProfiles(for: session, pool: pool)
        return try VCUserProfilesPage(session: session, profiles: profiles, error: "Could not create profile.").rootNode.response()
    }
}

@Sendable func userProfileDetailPage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try expiredSessionResponse()
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchOwnedProfile(req: req, session: session, pool: pool) else {
        let profiles = try await fetchUserProfiles(for: session, pool: pool)
        return try VCUserProfilesPage(session: session, profiles: profiles, error: "Profile not found.").rootNode.response()
    }
    return req.redirect(to: "/user/profile/\(profile.id.description)/games", redirectType: .normal)
}

@Sendable func userProfileGamesPage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try expiredSessionResponse()
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchOwnedProfile(req: req, session: session, pool: pool) else {
        let profiles = try await fetchUserProfiles(for: session, pool: pool)
        return try VCUserProfilesPage(session: session, profiles: profiles, error: "Profile not found.").rootNode.response()
    }
    let summaries = try await fetchProfileGameSummaries(userId: session.user, profile: profile, pool: pool)
    let state = ProfileGamesPageState(req: req)
    let filteredSummaries = filterProfileGameSummaries(summaries, state: state)
    let sortedSummaries = sortProfileGameSummaries(filteredSummaries, state: state)
    let (pageSummaries, hasNextPage) = pageProfileGameSummaries(sortedSummaries, state: state)
    let listPath = "/user/profile/\(profile.id.description)/games"
    return try VCProfileGamesPage(session: session, profile: profile, summaries: pageSummaries, totalCount: filteredSummaries.count, state: state, hasNextPage: hasNextPage, listPath: listPath, gameLinkBasePath: "/user/profile/\(profile.id.description)/games-family", backLinkPath: "/user/profiles", error: nil).rootNode.response()
}

@Sendable func userProfileGameSavesPage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try expiredSessionResponse()
    }
    guard let familyId: UUID = req.parameters.get("family_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchOwnedProfile(req: req, session: session, pool: pool) else {
        let profiles = try await fetchUserProfiles(for: session, pool: pool)
        return try VCUserProfilesPage(session: session, profiles: profiles, error: "Profile not found.").rootNode.response()
    }
    guard let familyData = try await fetchProfileGameFamily(userId: session.user, profile: profile, familyId: familyId, pool: pool) else {
        let summaries = try await fetchProfileGameSummaries(userId: session.user, profile: profile, pool: pool)
        let state = ProfileGamesPageState(req: req)
        let filteredSummaries = filterProfileGameSummaries(summaries, state: state)
        let sortedSummaries = sortProfileGameSummaries(filteredSummaries, state: state)
        let (pageSummaries, hasNextPage) = pageProfileGameSummaries(sortedSummaries, state: state)
        let listPath = "/user/profile/\(profile.id.description)/games"
        return try VCProfileGamesPage(session: session, profile: profile, summaries: pageSummaries, totalCount: filteredSummaries.count, state: state, hasNextPage: hasNextPage, listPath: listPath, gameLinkBasePath: "/user/profile/\(profile.id.description)/games-family", backLinkPath: "/user/profiles", error: "Game family not found.").rootNode.response()
    }
    let savesPath = "/user/profile/\(profile.id.description)/games-family/\(familyId.uuidString)"
    return try VCProfileGameSavesPage(session: session, profile: profile, familyData: familyData, rootLabel: "Profiles", rootLinkPath: "/user/profiles", backLinkPath: "/user/profile/\(profile.id.description)/games", downloadAllPath: "\(savesPath)/saves/download", deleteAllPath: "\(savesPath)/saves/delete", saveBasePath: "/user/profile/\(profile.id.description)/saves", deleteSequenceBasePath: "\(savesPath)/saves", sequenceBasePath: "/user/profile/\(profile.id.description)/saves-sequence", error: nil).rootNode.response()
}

@Sendable func userProfileGameSavesDownloadPage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try expiredSessionResponse()
    }
    guard let familyId: UUID = req.parameters.get("family_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchOwnedProfile(req: req, session: session, pool: pool),
          let familyData = try await fetchProfileGameFamily(userId: session.user, profile: profile, familyId: familyId, pool: pool) else {
        let profiles = try await fetchUserProfiles(for: session, pool: pool)
        return try VCUserProfilesPage(session: session, profiles: profiles, error: "Profile or game not found.").rootNode.response()
    }
    return try VCProfileGameSavesDownloadPage(session: session, familyData: familyData, saveBasePath: "/user/profile/\(profile.id.description)/saves", backLinkPath: "/user/profile/\(profile.id.description)/games-family/\(familyId.uuidString)").rootNode.response()
}

@Sendable func userProfileSaveDownload(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try expiredSessionResponse()
    }
    guard let saveId: UUID = req.parameters.get("save_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchOwnedProfile(req: req, session: session, pool: pool),
          let save = try await fetchProfileSave(userId: session.user, profile: profile, saveId: saveId, pool: pool) else {
        let profiles = try await fetchUserProfiles(for: session, pool: pool)
        return try VCUserProfilesPage(session: session, profiles: profiles, error: "Profile or save not found.").rootNode.response()
    }
    return req.redirect(to: save.url, redirectType: .normal)
}

@Sendable func userProfileSaveSequencePage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try expiredSessionResponse()
    }
    guard let sequenceId: UUID = req.parameters.get("sequence_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchOwnedProfile(req: req, session: session, pool: pool),
          let sequenceData = try await fetchProfileSaveSequence(userId: session.user, profile: profile, sequenceId: sequenceId, pool: pool) else {
        let profiles = try await fetchUserProfiles(for: session, pool: pool)
        return try VCUserProfilesPage(session: session, profiles: profiles, error: "Profile or save sequence not found.").rootNode.response()
    }
    let familyId = profileGameFamilyId(sequenceData.displayGame)
    return try VCProfileSaveSequencePage(
        session: session,
        profile: profile,
        sequenceData: sequenceData,
        rootLabel: "Profiles",
        rootLinkPath: "/user/profiles",
        profileLinkPath: "/user/profile/\(profile.id.description)/games",
        gameLinkPath: "/user/profile/\(profile.id.description)/games-family/\(familyId.uuidString)",
        backLinkPath: "/user/profile/\(profile.id.description)/games-family/\(familyId.uuidString)",
        saveBasePath: "/user/profile/\(profile.id.description)/saves",
        error: nil
    ).rootNode.response()
}

@Sendable func deleteUserProfileGameSavesPage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try expiredSessionResponse()
    }
    guard let familyId: UUID = req.parameters.get("family_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchOwnedProfile(req: req, session: session, pool: pool),
          let familyData = try await fetchProfileGameFamily(userId: session.user, profile: profile, familyId: familyId, pool: pool) else {
        let profiles = try await fetchUserProfiles(for: session, pool: pool)
        return try VCUserProfilesPage(session: session, profiles: profiles, error: "Profile or game not found.").rootNode.response()
    }
    let sequentialId: UUID? = req.parameters.get("sequential_id")
    let sequenceGroup = sequentialId.flatMap { findSequenceGroup($0, in: familyData) }
    if sequentialId != nil && sequenceGroup == nil {
        throw Abort(.notFound)
    }
    let basePath = "/user/profile/\(profile.id.description)/games-family/\(familyId.uuidString)"
    let deletePath = sequentialId.map { "\(basePath)/saves/\($0.uuidString)/delete" } ?? "\(basePath)/saves/delete"
    return try VCDeleteProfileGameSavesPage(session: session, profile: profile, familyData: familyData, deletePath: deletePath, cancelPath: basePath, sequenceGroup: sequenceGroup).rootNode.response()
}

@Sendable func deleteUserProfileGameSaves(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try expiredSessionResponse()
    }
    guard let familyId: UUID = req.parameters.get("family_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchOwnedProfile(req: req, session: session, pool: pool) else {
        let profiles = try await fetchUserProfiles(for: session, pool: pool)
        return try VCUserProfilesPage(session: session, profiles: profiles, error: "Profile not found.").rootNode.response()
    }
    let sequentialId: UUID? = req.parameters.get("sequential_id")
    try await deleteProfileGameFamilySaves(userId: session.user, profile: profile, familyId: familyId, sequentialId: sequentialId, pool: pool)
    return req.redirect(to: "/user/profile/\(profile.id.description)/games-family/\(familyId.uuidString)", redirectType: .normal)
}

@Sendable func deleteUserProfileSavePage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try expiredSessionResponse()
    }
    guard let saveId: UUID = req.parameters.get("save_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchOwnedProfile(req: req, session: session, pool: pool),
          let save = try await fetchProfileSave(userId: session.user, profile: profile, saveId: saveId, pool: pool) else {
        let profiles = try await fetchUserProfiles(for: session, pool: pool)
        return try VCUserProfilesPage(session: session, profiles: profiles, error: "Profile or save not found.").rootNode.response()
    }
    let game = try await pool.read { db -> GameMeta? in
        guard let gameId = save.gameMetaId else {
            return nil
        }
        return try GameMeta.filter(id: gameId).fetchOne(db)
    }
    let cancelPath = "/user/profile/\(profile.id.description)/saves-sequence/\(save.sequentialId.uuidString)"
    return try VCDeleteProfileSavePage(session: session, profile: profile, game: game, save: save, deletePath: "/user/profile/\(profile.id.description)/saves/\(save.id.uuidString)/delete", cancelPath: cancelPath).rootNode.response()
}

@Sendable func deleteUserProfileSave(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try expiredSessionResponse()
    }
    guard let saveId: UUID = req.parameters.get("save_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchOwnedProfile(req: req, session: session, pool: pool),
          let save = try await fetchProfileSave(userId: session.user, profile: profile, saveId: saveId, pool: pool) else {
        let profiles = try await fetchUserProfiles(for: session, pool: pool)
        return try VCUserProfilesPage(session: session, profiles: profiles, error: "Profile or save not found.").rootNode.response()
    }
    let sequenceId = save.sequentialId
    try await deleteProfileSave(userId: session.user, profile: profile, saveId: save.id, pool: pool)
    return req.redirect(to: "/user/profile/\(profile.id.description)/saves-sequence/\(sequenceId.uuidString)", redirectType: .normal)
}

@Sendable func managedUserProfileGamesPage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession(), session.isAdmin else {
        return try VCWelcomePage(users: [], error: "Admin access required.").rootNode.response()
    }
    guard let userId: SmallUid = req.parameters.get("user_id"),
          let profileId: SmallUid = req.parameters.get("profile_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchProfile(userId: userId, profileId: profileId, pool: pool) else {
        return try VCEditAllUsersPage(session: session, users: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "Profile not found.").rootNode.response()
    }
    let summaries = try await fetchProfileGameSummaries(userId: userId, profile: profile, pool: pool)
    let state = ProfileGamesPageState(req: req)
    let filteredSummaries = filterProfileGameSummaries(summaries, state: state)
    let sortedSummaries = sortProfileGameSummaries(filteredSummaries, state: state)
    let (pageSummaries, hasNextPage) = pageProfileGameSummaries(sortedSummaries, state: state)
    let userIdText = userId.description
    let listPath = "/users/\(userIdText)/profiles/\(profile.id.description)/games"
    return try VCProfileGamesPage(session: session, profile: profile, summaries: pageSummaries, totalCount: filteredSummaries.count, state: state, hasNextPage: hasNextPage, listPath: listPath, gameLinkBasePath: "/users/\(userIdText)/profiles/\(profile.id.description)/games-family", backLinkPath: "/users/\(userIdText)", error: nil).rootNode.response()
}

@Sendable func managedUserProfileGameSavesPage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession(), session.isAdmin else {
        return try VCWelcomePage(users: [], error: "Admin access required.").rootNode.response()
    }
    guard let userId: SmallUid = req.parameters.get("user_id"),
          let profileId: SmallUid = req.parameters.get("profile_id"),
          let familyId: UUID = req.parameters.get("family_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchProfile(userId: userId, profileId: profileId, pool: pool) else {
        return try VCEditAllUsersPage(session: session, users: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "Profile not found.").rootNode.response()
    }
    guard let familyData = try await fetchProfileGameFamily(userId: userId, profile: profile, familyId: familyId, pool: pool) else {
        let summaries = try await fetchProfileGameSummaries(userId: userId, profile: profile, pool: pool)
        let state = ProfileGamesPageState(req: req)
        let filteredSummaries = filterProfileGameSummaries(summaries, state: state)
        let sortedSummaries = sortProfileGameSummaries(filteredSummaries, state: state)
        let (pageSummaries, hasNextPage) = pageProfileGameSummaries(sortedSummaries, state: state)
        let userIdText = userId.description
        let listPath = "/users/\(userIdText)/profiles/\(profile.id.description)/games"
        return try VCProfileGamesPage(session: session, profile: profile, summaries: pageSummaries, totalCount: filteredSummaries.count, state: state, hasNextPage: hasNextPage, listPath: listPath, gameLinkBasePath: "/users/\(userIdText)/profiles/\(profile.id.description)/games-family", backLinkPath: "/users/\(userIdText)", error: "Game family not found.").rootNode.response()
    }
    let userIdText = userId.description
    let savesPath = "/users/\(userIdText)/profiles/\(profile.id.description)/games-family/\(familyId.uuidString)"
    return try VCProfileGameSavesPage(session: session, profile: profile, familyData: familyData, rootLabel: "User", rootLinkPath: "/users/\(userIdText)", backLinkPath: "/users/\(userIdText)/profiles/\(profile.id.description)/games", downloadAllPath: "\(savesPath)/saves/download", deleteAllPath: "\(savesPath)/saves/delete", saveBasePath: "/users/\(userIdText)/profiles/\(profile.id.description)/saves", deleteSequenceBasePath: "\(savesPath)/saves", sequenceBasePath: "/users/\(userIdText)/profiles/\(profile.id.description)/saves-sequence", error: nil).rootNode.response()
}

@Sendable func managedUserProfileGameSavesDownloadPage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession(), session.isAdmin else {
        return try VCWelcomePage(users: [], error: "Admin access required.").rootNode.response()
    }
    guard let userId: SmallUid = req.parameters.get("user_id"),
          let profileId: SmallUid = req.parameters.get("profile_id"),
          let familyId: UUID = req.parameters.get("family_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchProfile(userId: userId, profileId: profileId, pool: pool),
          let familyData = try await fetchProfileGameFamily(userId: userId, profile: profile, familyId: familyId, pool: pool) else {
        return try VCEditAllUsersPage(session: session, users: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "Profile or game not found.").rootNode.response()
    }
    let userIdText = userId.description
    return try VCProfileGameSavesDownloadPage(session: session, familyData: familyData, saveBasePath: "/users/\(userIdText)/profiles/\(profile.id.description)/saves", backLinkPath: "/users/\(userIdText)/profiles/\(profile.id.description)/games-family/\(familyId.uuidString)").rootNode.response()
}

@Sendable func managedUserProfileSaveDownload(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession(), session.isAdmin else {
        return try VCWelcomePage(users: [], error: "Admin access required.").rootNode.response()
    }
    guard let userId: SmallUid = req.parameters.get("user_id"),
          let profileId: SmallUid = req.parameters.get("profile_id"),
          let saveId: UUID = req.parameters.get("save_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchProfile(userId: userId, profileId: profileId, pool: pool),
          let save = try await fetchProfileSave(userId: userId, profile: profile, saveId: saveId, pool: pool) else {
        return try VCEditAllUsersPage(session: session, users: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "Profile or save not found.").rootNode.response()
    }
    return req.redirect(to: save.url, redirectType: .normal)
}

@Sendable func managedUserProfileSaveSequencePage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession(), session.isAdmin else {
        return try VCWelcomePage(users: [], error: "Admin access required.").rootNode.response()
    }
    guard let userId: SmallUid = req.parameters.get("user_id"),
          let profileId: SmallUid = req.parameters.get("profile_id"),
          let sequenceId: UUID = req.parameters.get("sequence_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchProfile(userId: userId, profileId: profileId, pool: pool),
          let sequenceData = try await fetchProfileSaveSequence(userId: userId, profile: profile, sequenceId: sequenceId, pool: pool) else {
        return try VCEditAllUsersPage(session: session, users: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "Profile or save sequence not found.").rootNode.response()
    }
    let familyId = profileGameFamilyId(sequenceData.displayGame)
    return try VCProfileSaveSequencePage(
        session: session,
        profile: profile,
        sequenceData: sequenceData,
        rootLabel: "User",
        rootLinkPath: "/users/\(userId.description)",
        profileLinkPath: "/users/\(userId.description)/profiles/\(profile.id.description)/games",
        gameLinkPath: "/users/\(userId.description)/profiles/\(profile.id.description)/games-family/\(familyId.uuidString)",
        backLinkPath: "/users/\(userId.description)/profiles/\(profile.id.description)/games-family/\(familyId.uuidString)",
        saveBasePath: "/users/\(userId.description)/profiles/\(profile.id.description)/saves",
        error: nil
    ).rootNode.response()
}

@Sendable func deleteManagedUserProfileGameSavesPage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession(), session.isAdmin else {
        return try VCWelcomePage(users: [], error: "Admin access required.").rootNode.response()
    }
    guard let userId: SmallUid = req.parameters.get("user_id"),
          let profileId: SmallUid = req.parameters.get("profile_id"),
          let familyId: UUID = req.parameters.get("family_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchProfile(userId: userId, profileId: profileId, pool: pool),
          let familyData = try await fetchProfileGameFamily(userId: userId, profile: profile, familyId: familyId, pool: pool) else {
        return try VCEditAllUsersPage(session: session, users: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "Profile or game not found.").rootNode.response()
    }
    let sequentialId: UUID? = req.parameters.get("sequential_id")
    let sequenceGroup = sequentialId.flatMap { findSequenceGroup($0, in: familyData) }
    if sequentialId != nil && sequenceGroup == nil {
        throw Abort(.notFound)
    }
    let basePath = "/users/\(userId.description)/profiles/\(profile.id.description)/games-family/\(familyId.uuidString)"
    let deletePath = sequentialId.map { "\(basePath)/saves/\($0.uuidString)/delete" } ?? "\(basePath)/saves/delete"
    return try VCDeleteProfileGameSavesPage(session: session, profile: profile, familyData: familyData, deletePath: deletePath, cancelPath: basePath, sequenceGroup: sequenceGroup).rootNode.response()
}

@Sendable func deleteManagedUserProfileGameSaves(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession(), session.isAdmin else {
        return try VCWelcomePage(users: [], error: "Admin access required.").rootNode.response()
    }
    guard let userId: SmallUid = req.parameters.get("user_id"),
          let profileId: SmallUid = req.parameters.get("profile_id"),
          let familyId: UUID = req.parameters.get("family_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchProfile(userId: userId, profileId: profileId, pool: pool) else {
        return try VCEditAllUsersPage(session: session, users: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "Profile not found.").rootNode.response()
    }
    let sequentialId: UUID? = req.parameters.get("sequential_id")
    try await deleteProfileGameFamilySaves(userId: userId, profile: profile, familyId: familyId, sequentialId: sequentialId, pool: pool)
    return req.redirect(to: "/users/\(userId.description)/profiles/\(profile.id.description)/games-family/\(familyId.uuidString)", redirectType: .normal)
}

@Sendable func deleteManagedUserProfileSavePage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession(), session.isAdmin else {
        return try VCWelcomePage(users: [], error: "Admin access required.").rootNode.response()
    }
    guard let userId: SmallUid = req.parameters.get("user_id"),
          let profileId: SmallUid = req.parameters.get("profile_id"),
          let saveId: UUID = req.parameters.get("save_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchProfile(userId: userId, profileId: profileId, pool: pool),
          let save = try await fetchProfileSave(userId: userId, profile: profile, saveId: saveId, pool: pool) else {
        return try VCEditAllUsersPage(session: session, users: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "Profile or save not found.").rootNode.response()
    }
    let game = try await pool.read { db -> GameMeta? in
        guard let gameId = save.gameMetaId else {
            return nil
        }
        return try GameMeta.filter(id: gameId).fetchOne(db)
    }
    let basePath = "/users/\(userId.description)/profiles/\(profile.id.description)"
    return try VCDeleteProfileSavePage(session: session, profile: profile, game: game, save: save, deletePath: "\(basePath)/saves/\(save.id.uuidString)/delete", cancelPath: "\(basePath)/saves-sequence/\(save.sequentialId.uuidString)").rootNode.response()
}

@Sendable func deleteManagedUserProfileSave(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession(), session.isAdmin else {
        return try VCWelcomePage(users: [], error: "Admin access required.").rootNode.response()
    }
    guard let userId: SmallUid = req.parameters.get("user_id"),
          let profileId: SmallUid = req.parameters.get("profile_id"),
          let saveId: UUID = req.parameters.get("save_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchProfile(userId: userId, profileId: profileId, pool: pool),
          let save = try await fetchProfileSave(userId: userId, profile: profile, saveId: saveId, pool: pool) else {
        return try VCEditAllUsersPage(session: session, users: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "Profile or save not found.").rootNode.response()
    }
    let sequenceId = save.sequentialId
    try await deleteProfileSave(userId: userId, profile: profile, saveId: save.id, pool: pool)
    return req.redirect(to: "/users/\(userId.description)/profiles/\(profile.id.description)/saves-sequence/\(sequenceId.uuidString)", redirectType: .normal)
}
