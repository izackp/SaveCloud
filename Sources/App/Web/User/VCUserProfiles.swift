import Vapor
import HRW
import GRDB

private struct UserProfileCreateRequest: Content {
    let id: String
    let name: String

    func validate() -> String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Name is empty."
        }
        if UUID(uuidString: id) == nil {
            return "Profile ID is invalid."
        }
        return nil
    }
}

final class VCProfileGridItem: ProfileGridItem {
    init(profile: UserProfile) throws {
        try super.init()
        profile_link.href = URL(string: "/user/profile/\(profile.id.uuidString)/games")
        let profileId = profile.id.uuidString.uppercased()
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
        let profileId = profile.id.uuidString.uppercased()
        profile_avatar_container.addChild(HTMLText(content: #"<svg width="120" height="120" data-jdenticon-value="\#(profileId)"></svg>"#))
        profile_id.addChild(HTMLText(content: profile.id.uuidString))
        name.addChild(HTMLText(content: profile.name))
        profile_id_record.addChild(HTMLText(content: profile.id.uuidString))
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

final class VCProfileGamesTableRow: ProfileGamesTableRow {
    init(summary: ProfileGameSummary) throws {
        try super.init()
        game_name.addChild(HTMLText(content: summary.game.name))
        game_link.href = URL(string: "/games/\(summary.game.id.uuidString)")
        version.addChild(HTMLText(content: summary.game.version ?? "N/A"))
        let latestDate = summary.latestSaveDate
        latest_save_date.addChild(HTMLText(content: shortProfileSaveDateText(latestDate)))
        latest_save_date.globalAttributes[.title] = fullProfileSaveDateText(latestDate)
        save_name.addChild(HTMLText(content: summary.latestSave.name ?? ""))
    }
}

final class VCProfileGamesPage: ProfileGamesPage {
    init(session: AuthSession, profile: UserProfile, summaries: [ProfileGameSummary], backLinkPath: String, error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        if let error {
            p_error.addChild(HTMLText(content: error))
            p_error.globalAttributes[.style] = ""
        }
        title.addChild(HTMLText(content: profile.name))
        let profileId = profile.id.uuidString.uppercased()
        profile_avatar_container.addChild(HTMLText(content: #"<svg width="120" height="120" data-jdenticon-value="\#(profileId)"></svg>"#))
        profile_id.addChild(HTMLText(content: profile.id.uuidString))
        let summaryCopy = summaries.count == 1 ? "1 game with saves" : "\(summaries.count) games with saves"
        summary_text.addChild(HTMLText(content: summaryCopy))
        if summaries.isEmpty {
            empty_text.globalAttributes[.style] = ""
        } else {
            for summary in summaries {
                table.children.append(try VCProfileGamesTableRow(summary: summary).rootNode)
            }
        }
        back_link.href = URL(string: backLinkPath)
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
    guard let profileId: UUID = req.parameters.get("profile_id") else {
        return nil
    }
    return try await pool.read { db in
        try UserProfile
            .filter(id: profileId)
            .filter(UserProfile.user_id == session.user)
            .fetchOne(db)
    }
}

private func fetchProfile(userId: UUID, profileId: UUID, pool: DatabasePool) async throws -> UserProfile? {
    try await pool.read { db in
        try UserProfile
            .filter(id: profileId)
            .filter(UserProfile.user_id == userId)
            .fetchOne(db)
    }
}

private func fetchProfileGameSummaries(userId: UUID, profile: UserProfile, pool: DatabasePool) async throws -> [ProfileGameSummary] {
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

@Sendable func userProfilesPage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try VCWelcomePage(users: [], error: "Session doesn't exist").rootNode.response()
    }
    let pool = DBShared.pool()
    let profiles = try await fetchUserProfiles(for: session, pool: pool)
    return try VCUserProfilesPage(session: session, profiles: profiles, error: nil).rootNode.response()
}

@Sendable func createUserProfile(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try VCWelcomePage(users: [], error: "Session doesn't exist").rootNode.response()
    }
    let contents = try req.content.decode(UserProfileCreateRequest.self)
    if let error = contents.validate() {
        let profiles = try await fetchUserProfiles(for: session, pool: DBShared.pool())
        return try VCUserProfilesPage(session: session, profiles: profiles, error: error).rootNode.response()
    }

    let profileId = UUID(uuidString: contents.id)!
    let trimmedName = contents.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let date = Date()
    let pool = DBShared.pool()

    do {
        let profile = try await pool.write { db in
            var profile = UserProfile(id: profileId, userId: session.user, name: trimmedName, createdAt: date, updatedAt: date)
            try profile.insert(db)
            return profile
        }
        return req.redirect(to: "/user/profile/\(profile.id.uuidString)/games", redirectType: .normal)
    } catch {
        let profiles = try await fetchUserProfiles(for: session, pool: pool)
        return try VCUserProfilesPage(session: session, profiles: profiles, error: "Could not create profile.").rootNode.response()
    }
}

@Sendable func userProfileDetailPage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try VCWelcomePage(users: [], error: "Session doesn't exist").rootNode.response()
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchOwnedProfile(req: req, session: session, pool: pool) else {
        let profiles = try await fetchUserProfiles(for: session, pool: pool)
        return try VCUserProfilesPage(session: session, profiles: profiles, error: "Profile not found.").rootNode.response()
    }
    return req.redirect(to: "/user/profile/\(profile.id.uuidString)/games", redirectType: .normal)
}

@Sendable func userProfileGamesPage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try VCWelcomePage(users: [], error: "Session doesn't exist").rootNode.response()
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchOwnedProfile(req: req, session: session, pool: pool) else {
        let profiles = try await fetchUserProfiles(for: session, pool: pool)
        return try VCUserProfilesPage(session: session, profiles: profiles, error: "Profile not found.").rootNode.response()
    }
    let summaries = try await fetchProfileGameSummaries(userId: session.user, profile: profile, pool: pool)
    return try VCProfileGamesPage(session: session, profile: profile, summaries: summaries, backLinkPath: "/user/profiles", error: nil).rootNode.response()
}

@Sendable func managedUserProfileGamesPage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession(), session.isAdmin else {
        return try VCWelcomePage(users: [], error: "Admin access required.").rootNode.response()
    }
    guard let userId: UUID = req.parameters.get("user_id"),
          let profileId: UUID = req.parameters.get("profile_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchProfile(userId: userId, profileId: profileId, pool: pool) else {
        return try VCEditAllUsersPage(session: session, users: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "Profile not found.").rootNode.response()
    }
    let summaries = try await fetchProfileGameSummaries(userId: userId, profile: profile, pool: pool)
    return try VCProfileGamesPage(session: session, profile: profile, summaries: summaries, backLinkPath: "/users/\(userId.uuidString)", error: nil).rootNode.response()
}
