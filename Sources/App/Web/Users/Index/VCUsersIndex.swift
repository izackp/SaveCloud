import Vapor
import HRW

final class VCEditAllUsersTableRow: EditAllUsersTableRow {
    init(user: User) throws {
        try super.init()
        username.addChild(HTMLText(content: user.username))
        username_link.href = URL(string: "/users/\(user.id.description)")
        email.addChild(HTMLText(content: user.email ?? ""))
        is_admin.addChild(HTMLText(content: user.isAdmin ? "Yes" : "No"))
        created_at.addChild(HTMLText(content: shortManagedUserDateText(user.createdAt)))
        created_at.globalAttributes[.title] = fullManagedUserDateText(user.createdAt)
        updated_at.addChild(HTMLText(content: shortManagedUserDateText(user.updatedAt)))
        updated_at.globalAttributes[.title] = fullManagedUserDateText(user.updatedAt)
        edit_link.href = URL(string: "/user/edit_all/\(user.id.description)/edit")
        delete_link.href = URL(string: "/user/edit_all/\(user.id.description)/delete")
    }
}

final class VCEditAllUsersPage: EditAllUsersPage {
    init(session: AuthSession, users: [User], pageInfo: ManagedUserPageInfo, hasNextPage: Bool, error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        if let error {
            p_error.addChild(HTMLText(content: error))
            p_error.globalAttributes[.style] = ""
        }
        for user in users {
            table.children.append(try VCEditAllUsersTableRow(user: user).rootNode)
        }
        page_text.addChild(HTMLText(content: "Page \(pageInfo.page + 1)"))
        if pageInfo.page > 0 {
            prev_link.href = URL(string: "/user/edit_all?\(pageInfo.queryString(page: pageInfo.page - 1))")
            prev_link.globalAttributes[.style] = ""
        }
        if hasNextPage {
            next_link.href = URL(string: "/user/edit_all?\(pageInfo.queryString(page: pageInfo.page + 1))")
            next_link.globalAttributes[.style] = ""
        }
    }
}

@Sendable func editAllUsers(req: Request) async throws -> Response {
    guard let session = try await adminSession(for: req) else {
        return try adminAccessDeniedResponse()
    }

    let pageInfo = ManagedUserPageInfo(req: req)
    let pool = DBShared.pool()
    let users = try await pool.read { db in
        try User
            .order(User.username.asc)
            .limit(Int(pageInfo.perPage) + 1, offset: Int(pageInfo.page * pageInfo.perPage))
            .fetchAll(db)
    }
    let hasNextPage = users.count > Int(pageInfo.perPage)
    let pageUsers = Array(users.prefix(Int(pageInfo.perPage)))
    return try VCEditAllUsersPage(session: session, users: pageUsers, pageInfo: pageInfo, hasNextPage: hasNextPage, error: nil).rootNode.response()
}
