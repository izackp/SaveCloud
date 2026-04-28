import Vapor
import HRW
import GRDB

final class VCEditSessionsTableRow: EditSessionsTableRow {
    init(session: AuthSession, context: SessionPageContext) throws {
        try super.init()
        session_id.addChild(HTMLText(content: session.id.uuidString))
        if context.isCurrent(session) {
            session_id.addChild(HTMLText(content: " (Current)"))
            rootNode.globalAttributes[.class_] = "is-current-session"
        }
        user_id.addChild(HTMLText(content: session.user.description))
        refresh_token.addChild(HTMLText(content: session.refreshToken?.uuidString ?? ""))
        device_name.addChild(HTMLText(content: session.deviceName ?? ""))
        location.addChild(HTMLText(content: session.location ?? ""))
        ip_address.addChild(HTMLText(content: session.ipAddress))
        is_admin.addChild(HTMLText(content: session.isAdmin ? "Yes" : "No"))
        expires_at.addChild(HTMLText(content: String(describing: session.expiresAt)))
        if context.canEdit {
            edit_link.href = URL(string: "\(context.basePath)/\(session.id.uuidString)/edit")
        } else {
            edit_link.globalAttributes[.style] = "display:none"
        }
        if context.canDelete(session) {
            delete_link.href = URL(string: "\(context.basePath)/\(session.id.uuidString)/delete")
        } else {
            delete_link.globalAttributes[.style] = "display:none"
        }
    }
}

final class VCEditSessionsPage: EditSessionsPage {
    init(context: SessionPageContext, sessions: [AuthSession], pageInfo: ManagedUserPageInfo, hasNextPage: Bool, error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: context.viewer.isAdmin).rootNode)
        if let error {
            p_error.addChild(HTMLText(content: error))
            p_error.globalAttributes[.style] = ""
        }
        for item in sessions {
            table.children.append(try VCEditSessionsTableRow(session: item, context: context).rootNode)
        }
        page_text.addChild(HTMLText(content: "Page \(pageInfo.page + 1)"))
        if pageInfo.page > 0 {
            prev_link.href = URL(string: "\(context.basePath)?\(pageInfo.queryString(page: pageInfo.page - 1))")
            prev_link.globalAttributes[.style] = ""
        }
        if hasNextPage {
            next_link.href = URL(string: "\(context.basePath)?\(pageInfo.queryString(page: pageInfo.page + 1))")
            next_link.globalAttributes[.style] = ""
        }
    }
}

@Sendable func editAllSessions(req: Request) async throws -> Response {
    guard let context = try await sessionPageContext(for: req) else {
        return try unauthorizedResponse()
    }

    let pageInfo = ManagedUserPageInfo(req: req)
    let pool = DBShared.pool()
    let sessions = try await pool.read { db in
        var request = AuthSession.order(AuthSession.created_at.desc)
        if let targetUserId = context.targetUserId {
            request = request.filter(AuthSession.user == targetUserId)
        }
        return try request
            .limit(Int(pageInfo.perPage) + 1, offset: Int(pageInfo.page * pageInfo.perPage))
            .fetchAll(db)
    }
    let hasNextPage = sessions.count > Int(pageInfo.perPage)
    let pageSessions = Array(sessions.prefix(Int(pageInfo.perPage)))
    return try VCEditSessionsPage(context: context, sessions: pageSessions, pageInfo: pageInfo, hasNextPage: hasNextPage, error: nil).rootNode.response()
}
