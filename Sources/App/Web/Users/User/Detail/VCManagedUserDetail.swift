import Vapor
import HRW

final class VCManagedUserProfileGridItem: ProfileGridItem {
    init(user: User, profile: UserProfile) throws {
        try super.init()
        profile_link.href = URL(string: "/profile/\(profile.id.description)/games")
        let profileId = profile.id.description
        profile_avatar_container.addChild(HTMLText(content: #"<svg width="80" height="80" data-jdenticon-value="\#(profileId)"></svg>"#))
        name.addChild(HTMLText(content: profile.name))
    }
}

final class VCManagedUserDetailPage: ManagedUserDetailPage {
    init(session: AuthSession, user: User, profiles: [UserProfile], error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        if let error {
            p_error.addChild(HTMLText(content: error))
            p_error.globalAttributes[.style] = ""
        }
        title.addChild(HTMLText(content: user.username))
        edit_link.href = URL(string: "/users/\(user.id.description)/edit")
        username.addChild(HTMLText(content: user.username))
        email.addChild(HTMLText(content: user.email ?? ""))
        is_admin.addChild(HTMLText(content: user.isAdmin ? "Yes" : "No"))
        user_id.addChild(HTMLText(content: user.id.description))
        created_at.addChild(HTMLText(content: String(describing: user.createdAt)))
        updated_at.addChild(HTMLText(content: String(describing: user.updatedAt)))
        if profiles.isEmpty {
            empty_profiles_text.globalAttributes[.style] = ""
        } else {
            for profile in profiles {
                profiles_container.children.append(try VCManagedUserProfileGridItem(user: user, profile: profile).rootNode)
            }
        }
        back_link.href = URL(string: "/user/edit_all")
    }
}

@Sendable func managedUserPageByUserId(req: Request) async throws -> Response {
    guard let session = try await adminSession(for: req) else {
        return try adminAccessDeniedResponse()
    }

    let pool = DBShared.pool()
    guard let user = try await fetchManagedUser(req: req, pool: pool) else {
        return try VCEditAllUsersPage(session: session, users: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "User not found.").rootNode.response()
    }
    let profiles = try await fetchProfiles(for: user, pool: pool)
    return try VCManagedUserDetailPage(session: session, user: user, profiles: profiles, error: nil).rootNode.response()
}
