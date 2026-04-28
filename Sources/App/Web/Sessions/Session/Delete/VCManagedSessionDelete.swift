import Vapor
import HRW

final class VCDeleteManagedSessionPage: DeleteManagedSessionPage {
    init(context: SessionPageContext, managedSession: AuthSession) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: context.viewer.isAdmin).rootNode)
        session_id.addChild(HTMLText(content: managedSession.id.uuidString))
        user_id.addChild(HTMLText(content: managedSession.user.description))
        device_name.addChild(HTMLText(content: managedSession.deviceName ?? ""))
        ip_address.addChild(HTMLText(content: managedSession.ipAddress))
        expires_at.addChild(HTMLText(content: String(describing: managedSession.expiresAt)))
        delete_form.action = URL(string: "\(context.basePath)/\(managedSession.id.uuidString)/delete")
        cancel_link.href = URL(string: context.basePath)
    }
}

@Sendable func deleteManagedSessionPage(req: Request) async throws -> Response {
    guard let context = try await sessionPageContext(for: req) else {
        return try unauthorizedResponse()
    }

    let pool = DBShared.pool()
    guard let managedSession = try await fetchManagedSession(req: req, pool: pool, targetUserId: context.targetUserId) else {
        return try VCEditSessionsPage(context: context, sessions: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "Session not found.").rootNode.response()
    }
    guard context.canDelete(managedSession) else {
        return try unauthorizedResponse()
    }
    return try VCDeleteManagedSessionPage(context: context, managedSession: managedSession).rootNode.response()
}

@Sendable func deleteManagedSession(req: Request) async throws -> Response {
    guard let context = try await sessionPageContext(for: req) else {
        return try unauthorizedResponse()
    }

    let pool = DBShared.pool()
    guard let managedSession = try await fetchManagedSession(req: req, pool: pool, targetUserId: context.targetUserId) else {
        return try VCEditSessionsPage(context: context, sessions: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "Session not found.").rootNode.response()
    }
    guard context.canDelete(managedSession) else {
        return try unauthorizedResponse()
    }

    _ = try await pool.write { db in
        try AuthSession.filter(id: managedSession.id).deleteAll(db)
    }

    if context.viewer.id == managedSession.id {
        let response = req.redirect(to: "/", redirectType: .normal)
        clearBrowserSessionCookie(on: response)
        return response
    }

    return req.redirect(to: context.basePath, redirectType: .normal)
}
