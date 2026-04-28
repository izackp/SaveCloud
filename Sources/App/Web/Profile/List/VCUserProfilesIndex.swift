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
        profile_link.href = URL(string: "/profile/\(profile.id.description)/games")
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

func fetchUserProfiles(for session: AuthSession, pool: DatabasePool) async throws -> [UserProfile] {
    try await pool.read { db in
        try UserProfile
            .filter(UserProfile.user_id == session.user)
            .order(UserProfile.name.asc)
            .fetchAll(db)
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
        return req.redirect(to: "/profile/\(profile.id.description)/games", redirectType: .normal)
    } catch {
        let profiles = try await fetchUserProfiles(for: session, pool: pool)
        return try VCUserProfilesPage(session: session, profiles: profiles, error: "Could not create profile.").rootNode.response()
    }
}
