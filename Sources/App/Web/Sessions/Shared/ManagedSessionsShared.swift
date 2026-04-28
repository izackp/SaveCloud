import Vapor
import HRW
import GRDB

struct ManagedSessionRequest: Content {
    let user_id: String
    let refresh_token: String?
    let device_name: String?
    let location: String?
    let ip_address: String
    let is_admin: String?
    let expires_at: String

    var isAdmin: Bool {
        is_admin != nil
    }

    func validate() -> String? {
        if SmallUid(user_id) == nil {
            return "User ID is invalid."
        }
        if let refresh_token, !refresh_token.isEmpty && UUID(uuidString: refresh_token) == nil {
            return "Refresh token is invalid."
        }
        if ip_address.isEmpty {
            return "IP Address is empty."
        }
        if ISO8601DateFormatter().date(from: expires_at) == nil {
            return "Expires At must be ISO-8601."
        }
        return nil
    }
}

struct SessionPageContext {
    let viewer: AuthSession
    let targetUserId: SmallUid?
    let basePath: String
    let canEdit: Bool

    func canDelete(_ session: AuthSession) -> Bool {
        viewer.isAdmin || viewer.user == session.user
    }

    func isCurrent(_ session: AuthSession) -> Bool {
        viewer.id == session.id
    }
}

func unauthorizedResponse() throws -> Response {
    try VCWelcomePage(users: [], error: "Unauthorized").rootNode.response()
}

func sessionPageContext(for req: Request) async throws -> SessionPageContext? {
    guard let viewer = try await req.fetchSession() else {
        return nil
    }

    if req.url.path == "/sessions" || req.url.path.hasPrefix("/sessions/") {
        guard viewer.isAdmin else {
            return nil
        }
        return SessionPageContext(
            viewer: viewer,
            targetUserId: nil,
            basePath: "/sessions",
            canEdit: true
        )
    }

    if let userId: SmallUid = req.parameters.get("user_id") {
        guard viewer.isAdmin || viewer.user == userId else {
            return nil
        }
        return SessionPageContext(
            viewer: viewer,
            targetUserId: userId,
            basePath: "/users/\(userId.description)/sessions",
            canEdit: viewer.isAdmin
        )
    }

    return SessionPageContext(
        viewer: viewer,
        targetUserId: viewer.user,
        basePath: "/user/sessions",
        canEdit: viewer.isAdmin
    )
}

func fetchManagedSession(req: Request, pool: DatabasePool, targetUserId: SmallUid?) async throws -> AuthSession? {
    guard let sessionId: UUID = req.parameters.get("managed_session_id") else {
        return nil
    }
    return try await pool.read { db in
        var request = AuthSession.filter(id: sessionId)
        if let targetUserId {
            request = request.filter(AuthSession.user == targetUserId)
        }
        return try request.fetchOne(db)
    }
}
