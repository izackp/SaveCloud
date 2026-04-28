import Vapor
import HRW

private func managedSessionFormError(_ context: SessionPageContext, managedSession: AuthSession, error: String) throws -> Response {
    try VCManagedSessionPage(context: context, managedSession: managedSession, error: error).rootNode.response()
}

final class VCManagedSessionForm: ManagedSessionForm {
    init(session: AuthSession, basePath: String, error: String?) throws {
        try super.init()
        rootNode.action = URL(string: "\(basePath)/\(session.id.uuidString)/edit")
        session_id.addChild(HTMLText(content: session.id.uuidString))
        user_id.value = session.user.description
        refresh_token.value = session.refreshToken?.uuidString ?? ""
        device_name.value = session.deviceName ?? ""
        location.value = session.location ?? ""
        ip_address.value = session.ipAddress
        is_admin.checked = session.isAdmin
        expires_at.value = ISO8601DateFormatter().string(from: session.expiresAt)
        created_at.addChild(HTMLText(content: String(describing: session.createdAt)))
        updated_at.addChild(HTMLText(content: String(describing: session.updatedAt)))
        if let error {
            span_error.addChild(HTMLText(content: error))
            error_container.globalAttributes[.style] = ""
        }
    }
}

final class VCManagedSessionPage: ManagedSessionPage {
    init(context: SessionPageContext, managedSession: AuthSession, error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: context.viewer.isAdmin).rootNode)
        form_container.addChild(try VCManagedSessionForm(session: managedSession, basePath: context.basePath, error: error).rootNode)
    }
}

@Sendable func editManagedSessionPage(req: Request) async throws -> Response {
    guard let context = try await sessionPageContext(for: req), context.canEdit else {
        return try adminAccessDeniedResponse()
    }

    let pool = DBShared.pool()
    guard let managedSession = try await fetchManagedSession(req: req, pool: pool, targetUserId: context.targetUserId) else {
        return try VCEditSessionsPage(context: context, sessions: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "Session not found.").rootNode.response()
    }
    return try VCManagedSessionPage(context: context, managedSession: managedSession, error: nil).rootNode.response()
}

@Sendable func updateManagedSession(req: Request) async throws -> Response {
    guard let context = try await sessionPageContext(for: req), context.canEdit else {
        return try adminAccessDeniedResponse()
    }

    let pool = DBShared.pool()
    guard let managedSession = try await fetchManagedSession(req: req, pool: pool, targetUserId: context.targetUserId) else {
        return try VCEditSessionsPage(context: context, sessions: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "Session not found.").rootNode.response()
    }

    let contents = try req.content.decode(ManagedSessionRequest.self)
    if let error = contents.validate() {
        return try managedSessionFormError(context, managedSession: managedSession, error: error)
    }

    let updatedSession = try await pool.write { db in
        var updated = managedSession
        updated.user = SmallUid(contents.user_id)!
        updated.refreshToken = contents.refresh_token?.isEmpty == false ? UUID(uuidString: contents.refresh_token!) : nil
        updated.deviceName = contents.device_name?.isEmpty == false ? contents.device_name : nil
        updated.location = contents.location?.isEmpty == false ? contents.location : nil
        updated.ipAddress = contents.ip_address
        updated.isAdmin = contents.isAdmin
        updated.expiresAt = ISO8601DateFormatter().date(from: contents.expires_at)!
        updated.updatedAt = Date()
        try updated.update(db)
        return updated
    }

    return try VCManagedSessionPage(context: context, managedSession: updatedSession, error: nil).rootNode.response()
}
