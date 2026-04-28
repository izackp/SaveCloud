import Vapor
import HRW
import GRDB

final class VCDeleteManagedUserPage: DeleteManagedUserPage {
    init(session: AuthSession, user: User) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        user_id.addChild(HTMLText(content: user.id.description))
        username.addChild(HTMLText(content: user.username))
        email.addChild(HTMLText(content: user.email ?? ""))
        is_admin.addChild(HTMLText(content: user.isAdmin ? "Yes" : "No"))
        delete_form.action = URL(string: "/user/edit_all/\(user.id.description)/delete")
        cancel_link.href = URL(string: "/user/edit_all")
    }
}

@Sendable func deleteManagedUserPage(req: Request) async throws -> Response {
    guard let session = try await adminSession(for: req) else {
        return try adminAccessDeniedResponse()
    }

    let pool = DBShared.pool()
    guard let user = try await fetchManagedUser(req: req, pool: pool) else {
        return try VCEditAllUsersPage(session: session, users: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "User not found.").rootNode.response()
    }
    return try VCDeleteManagedUserPage(session: session, user: user).rootNode.response()
}

@Sendable func deleteManagedUser(req: Request) async throws -> Response {
    guard let session = try await adminSession(for: req) else {
        return try adminAccessDeniedResponse()
    }

    let pool = DBShared.pool()
    guard let user = try await fetchManagedUser(req: req, pool: pool) else {
        return try VCEditAllUsersPage(session: session, users: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "User not found.").rootNode.response()
    }

    try await pool.write { db in
        try AuthSession.filter(AuthSession.user == user.id).deleteAll(db)
        try User.filter(id: user.id).deleteAll(db)
    }

    if session.user == user.id {
        let response = req.redirect(to: "/", redirectType: .normal)
        clearBrowserSessionCookie(on: response)
        return response
    }

    return req.redirect(to: "/user/edit_all", redirectType: .normal)
}
