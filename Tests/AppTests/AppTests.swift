@testable import App
import XCTVapor

final class AppTests: XCTestCase {
    var app: Application!
    var dbDirectory: String!
    
    override func setUp() async throws {
        dbDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .path
        try FileManager.default.createDirectory(
            atPath: dbDirectory,
            withIntermediateDirectories: true
        )
        app = try await Application.make(.testing)
        try await configure(app)
        _ = try DBShared.initDB(clearDB: true, path: dbDirectory)
    }
    
    override func tearDown() async throws {
        try await app.asyncShutdown()
        app = nil
        try? FileManager.default.removeItem(atPath: dbDirectory)
        dbDirectory = nil
    }
    
    func testAPILoginReturnsSessionIdAndUser() async throws {
        let registeredUser = try await registerUser(
            username: "tester",
            email: "tester@example.com",
            password: "password123"
        )
        
        var loginPair: LoginPair?
        try await app.test(.POST, "api/v1/login", beforeRequest: { req in
            try req.content.encode(ApiLoginRequest(
                username: "tester",
                email: nil,
                password: "password123"
            ))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            loginPair = try res.content.decode(LoginPair.self)
        })
        
        let result = try XCTUnwrap(loginPair)
        XCTAssertFalse(result.token.sessionId.isEmpty)
        XCTAssertEqual(result.user.id, registeredUser.id)
        XCTAssertEqual(result.user.username, registeredUser.username)
        XCTAssertEqual(result.user.email, registeredUser.email)
    }
    
    func testAPIUserEndpointAcceptsBearerSessionId() async throws {
        let registeredUser = try await registerUser(
            username: "bearer-user",
            email: "bearer@example.com",
            password: "password123"
        )
        let loginPair = try await loginUser(
            username: "bearer-user",
            password: "password123"
        )
        
        try await app.test(.GET, "api/v1/user", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: loginPair.token.sessionId)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let user = try res.content.decode(PublicUser.self)
            XCTAssertEqual(user.id, registeredUser.id)
            XCTAssertEqual(user.username, registeredUser.username)
            XCTAssertEqual(user.email, registeredUser.email)
        })
    }
    
    func testExpiredAPISessionReturnsExplicitReason() async throws {
        let registeredUser = try await registerUser(
            username: "expired-user",
            email: "expired@example.com",
            password: "password123"
        )
        let expiredSession = try insertSession(
            userId: registeredUser.id,
            isAdmin: registeredUser.isAdmin,
            expiresAt: Date().advanced(by: -60)
        )
        
        try await app.test(.GET, "api/v1/user", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: expiredSession.id.uuidString)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .unauthorized)
            XCTAssertTrue(res.body.string.contains("Session expired"))
        })
    }
    
    func testAPISessionRenewsWhenCloseToDefaultExpiration() async throws {
        let registeredUser = try await registerUser(
            username: "renew-user",
            email: "renew@example.com",
            password: "password123"
        )
        let originalExpiration = Date().advanced(by: apiSessionRenewWindow - 60)
        let renewableSession = try insertSession(
            userId: registeredUser.id,
            isAdmin: registeredUser.isAdmin,
            expiresAt: originalExpiration
        )
        
        try await app.test(.GET, "api/v1/user", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: renewableSession.id.uuidString)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
        })
        
        let renewedSession = try await DBShared.pool().read { db in
            try AuthSession.filter(id: renewableSession.id).fetchOne(db)
        }
        let savedSession = try XCTUnwrap(renewedSession)
        XCTAssertGreaterThan(savedSession.expiresAt, originalExpiration)
        XCTAssertGreaterThan(savedSession.expiresAt, Date().advanced(by: apiSessionRenewWindow))
    }
    
    func testAPIGetUserByIdRejectsDifferentNonAdminUser() async throws {
        _ = try await registerUser(
            username: "admin-user",
            email: "admin@example.com",
            password: "password123"
        )
        _ = try await registerUser(
            username: "owner-user",
            email: "owner@example.com",
            password: "password123"
        )
        let otherUser = try await registerUser(
            username: "other-user",
            email: "other@example.com",
            password: "password123"
        )
        let ownerLogin = try await loginUser(
            username: "owner-user",
            password: "password123"
        )
        
        try await app.test(.GET, "api/v1/user/\(otherUser.id.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: ownerLogin.token.sessionId)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .unauthorized)
        })
    }
    
    func testAPIPutUserUpdatesAuthenticatedUser() async throws {
        let registeredUser = try await registerUser(
            username: "editable-user",
            email: "editable@example.com",
            password: "password123"
        )
        let loginPair = try await loginUser(
            username: "editable-user",
            password: "password123"
        )
        
        var updatedUser: PublicUser?
        try await app.test(.PUT, "api/v1/user", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: loginPair.token.sessionId)
            try req.content.encode(PutUser(
                id: registeredUser.id,
                username: "edited-user",
                email: "edited@example.com",
                isAdmin: nil
            ))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            updatedUser = try res.content.decode(PublicUser.self)
        })
        
        let result = try XCTUnwrap(updatedUser)
        XCTAssertEqual(result.id, registeredUser.id)
        XCTAssertEqual(result.username, "edited-user")
        XCTAssertEqual(result.email, "edited@example.com")
    }
    
    func testAPIPutUserRejectsDuplicateUsername() async throws {
        _ = try await registerUser(
            username: "first-user",
            email: "first@example.com",
            password: "password123"
        )
        let secondUser = try await registerUser(
            username: "second-user",
            email: "second@example.com",
            password: "password123"
        )
        let secondLogin = try await loginUser(
            username: "second-user",
            password: "password123"
        )
        
        try await app.test(.PUT, "api/v1/user", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: secondLogin.token.sessionId)
            try req.content.encode(PutUser(
                id: secondUser.id,
                username: "first-user",
                email: nil,
                isAdmin: nil
            ))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .badRequest)
            XCTAssertTrue(res.body.string.contains("already exists"))
        })
    }
    
    func testAPIDeleteUserRejectsWrongPassword() async throws {
        let registeredUser = try await registerUser(
            username: "delete-user",
            email: "delete@example.com",
            password: "password123"
        )
        let loginPair = try await loginUser(
            username: "delete-user",
            password: "password123"
        )
        
        try await app.test(.DELETE, "api/v1/user/\(registeredUser.id.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: loginPair.token.sessionId)
            try req.content.encode(PasswordCheck(password: "wrong-password"))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .unauthorized)
            XCTAssertTrue(res.body.string.contains("Incorrect password"))
        })
    }
    
    func testAPIDeleteUserDeletesUserAndSessions() async throws {
        let registeredUser = try await registerUser(
            username: "remove-user",
            email: "remove@example.com",
            password: "password123"
        )
        let loginPair = try await loginUser(
            username: "remove-user",
            password: "password123"
        )
        
        try await app.test(.DELETE, "api/v1/user/\(registeredUser.id.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: loginPair.token.sessionId)
            try req.content.encode(PasswordCheck(password: "password123"))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let deletedUser = try res.content.decode(PublicUser.self)
            XCTAssertEqual(deletedUser.id, registeredUser.id)
        })
        
        try await app.test(.GET, "api/v1/user", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: loginPair.token.sessionId)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .unauthorized)
        })
        
        let deletedUserId = registeredUser.id
        let fetchedUser = try await DBShared.pool().read { db in
            try User.filter(id: deletedUserId).fetchOne(db)
        }
        XCTAssertNil(fetchedUser)
    }
    
    private func registerUser(username: String, email: String, password: String) async throws -> PublicUser {
        var user: PublicUser?
        try await app.test(.POST, "api/v1/register", beforeRequest: { req in
            try req.content.encode(ApiRegisterRequest(
                username: username,
                email: email,
                password: password
            ))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            user = try res.content.decode(PublicUser.self)
        })
        return try XCTUnwrap(user)
    }
    
    private func loginUser(username: String, password: String) async throws -> LoginPair {
        var loginPair: LoginPair?
        try await app.test(.POST, "api/v1/login", beforeRequest: { req in
            try req.content.encode(ApiLoginRequest(
                username: username,
                email: nil,
                password: password
            ))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            loginPair = try res.content.decode(LoginPair.self)
        })
        return try XCTUnwrap(loginPair)
    }
    
    private func insertSession(userId: UUID, isAdmin: Bool, expiresAt: Date) throws -> AuthSession {
        let now = Date()
        let session = AuthSession(
            id: UUID(),
            refreshToken: nil,
            user: userId,
            deviceName: "tests",
            location: nil,
            ipAddress: "127.0.0.1",
            isAdmin: isAdmin,
            createdAt: now,
            updatedAt: now,
            expiresAt: expiresAt
        )
        try DBShared.pool().write { db in
            var saved = session
            try saved.insert(db)
        }
        return session
    }
}
