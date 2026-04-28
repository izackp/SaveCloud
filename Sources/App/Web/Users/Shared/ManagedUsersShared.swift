import Vapor
import Argon2Swift
import HRW
import GRDB

func shortManagedUserDateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "M/d HH:mm"
    return formatter.string(from: date)
}

func fullManagedUserDateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter.string(from: date)
}

struct ManagedUserPageInfo {
    let page: UInt
    let perPage: UInt

    init(req: Request) {
        page = (try? req.query.get(UInt.self, at: "page")) ?? 0
        let requestedPerPage = (try? req.query.get(UInt.self, at: "per_page")) ?? 20
        perPage = min(max(requestedPerPage, 1), 100)
    }

    func queryString(page: UInt) -> String {
        "page=\(page)&per_page=\(perPage)"
    }
}

struct ManagedUserRequest: Content {
    let username: String
    let email: String
    let password: String?
    let is_admin: String?

    var isAdmin: Bool {
        is_admin != nil
    }

    func validate(isNewUser: Bool) -> String? {
        if username.isEmpty {
            return "Username is empty."
        }
        if email.isEmpty {
            return "Email is empty."
        }
        if isNewUser && (password?.isEmpty != false) {
            return "Password is empty."
        }
        return nil
    }
}

func adminSession(for req: Request) async throws -> AuthSession? {
    guard let session = try await req.fetchSession(), session.isAdmin else {
        return nil
    }
    return session
}

func adminAccessDeniedResponse() throws -> Response {
    try VCWelcomePage(users: [], error: "Admin access required.").rootNode.response()
}

func fetchManagedUser(req: Request, pool: DatabasePool) async throws -> User? {
    guard let userId: SmallUid = req.parameters.get("managed_user_id") ?? req.parameters.get("user_id") else {
        return nil
    }
    return try await pool.read { db in
        try User.filter(id: userId).fetchOne(db)
    }
}

func fetchProfiles(for user: User, pool: DatabasePool) async throws -> [UserProfile] {
    try await pool.read { db in
        try UserProfile
            .filter(UserProfile.user_id == user.id)
            .order(UserProfile.name.asc)
            .fetchAll(db)
    }
}

func ensureUniqueManagedUserFields(pool: DatabasePool, username: String, email: String, excluding userId: SmallUid?) async throws -> String? {
    let duplicateUsername = try await pool.read { db in
        var request = User.filter(User.username == username)
        if let userId {
            request = request.filter(User.id != userId)
        }
        return try request.fetchCount(db) > 0
    }
    if duplicateUsername {
        return "Username \(username) already exists."
    }

    let duplicateEmail = try await pool.read { db in
        var request = User.filter(User.email == email)
        if let userId {
            request = request.filter(User.id != userId)
        }
        return try request.fetchCount(db) > 0
    }
    if duplicateEmail {
        return "Email \(email) is already in use."
    }

    return nil
}

func managedUserEditPath(for req: Request, user: User?) -> String? {
    guard let user else {
        return nil
    }
    if req.url.path == "/users/\(user.id.description)/edit" {
        return "/users/\(user.id.description)/edit"
    }
    return "/user/edit_all/\(user.id.description)/edit"
}

func managedUserFormError(_ session: AuthSession, req: Request, user: User?, error: String) throws -> Response {
    try VCManagedUserPage(session: session, user: user, editPath: managedUserEditPath(for: req, user: user), error: error).rootNode.response()
}
