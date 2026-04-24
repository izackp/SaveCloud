@testable import App
import GRDB
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

    func testAPIGameRoutesSupportCRUD() async throws {
        _ = try await registerUser(
            username: "games-admin",
            email: "games-admin@example.com",
            password: "password123"
        )
        let adminLogin = try await loginUser(
            username: "games-admin",
            password: "password123"
        )

        var createdGame: GameMeta?
        try await app.test(.POST, "api/v1/games", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminLogin.token.sessionId)
            try req.content.encode(GameMetaCreate(
                id: nil,
                name: "Test Game",
                version: "1.0",
                breaksSaveFormatFromPreviousVersion: false,
                breaksSaveFormatFromBaseGame: false
            ))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            createdGame = try res.content.decode(GameMeta.self)
        })

        let game = try XCTUnwrap(createdGame)

        try await app.test(.GET, "api/v1/games", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminLogin.token.sessionId)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let games = try res.content.decode([GameMeta].self)
            XCTAssertTrue(games.contains(where: { $0.id == game.id }))
        })

        try await app.test(.GET, "api/v1/games/\(game.id.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminLogin.token.sessionId)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let fetchedGame = try res.content.decode(GameMeta.self)
            XCTAssertEqual(fetchedGame.id, game.id)
            XCTAssertEqual(fetchedGame.name, "Test Game")
        })

        try await app.test(.PUT, "api/v1/games/\(game.id.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminLogin.token.sessionId)
            try req.content.encode(GameMetaCreate(
                id: nil,
                name: "Updated Game",
                version: "1.1",
                breaksSaveFormatFromPreviousVersion: true,
                breaksSaveFormatFromBaseGame: false
            ))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let updatedGame = try res.content.decode(GameMeta.self)
            XCTAssertEqual(updatedGame.id, game.id)
            XCTAssertEqual(updatedGame.name, "Updated Game")
            XCTAssertEqual(updatedGame.version, "1.1")
            XCTAssertTrue(updatedGame.breaksSaveFormatFromPreviousVersion)
        })

        try await app.test(.DELETE, "api/v1/games/\(game.id.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminLogin.token.sessionId)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
        })

        try await app.test(.GET, "api/v1/games/\(game.id.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminLogin.token.sessionId)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .notFound)
        })
    }

    func testAPIGameRoutesSupportHashFamilyAndProfileQueries() async throws {
        _ = try await registerUser(
            username: "games-query-admin",
            email: "games-query-admin@example.com",
            password: "password123"
        )
        let adminLogin = try await loginUser(
            username: "games-query-admin",
            password: "password123"
        )
        let adminSession = try await currentSession(for: adminLogin.token.sessionId)
        let familyId = UUID()
        let includedGame = try insertGameMeta(name: "Alpha Game", familyId: familyId)
        let excludedGame = try insertGameMeta(name: "Zulu Game", familyId: UUID())
        let hash = try insertGameHash(gameMetaId: includedGame.id, hash: "family-hash")
        let profile = try insertProfile(userId: adminSession.user, name: "Family Profile")
        _ = try insertSave(
            userId: adminSession.user,
            profileId: profile.id,
            gameHashId: hash.id,
            gameMetaId: includedGame.id,
            name: "Included Save"
        )

        try await app.test(.GET, "api/v1/games?hash=family-hash", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminLogin.token.sessionId)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let games = try res.content.decode([GameMeta].self)
            XCTAssertEqual(games.map(\.id), [includedGame.id])
        })

        try await app.test(.GET, "api/v1/games/\(includedGame.id.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminLogin.token.sessionId)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let game = try res.content.decode(GameMeta.self)
            XCTAssertEqual(game.id, includedGame.id)
        })

        try await app.test(.GET, "api/v1/games/by_family/\(familyId.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminLogin.token.sessionId)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let games = try res.content.decode([GameMeta].self)
            XCTAssertEqual(games.map(\.id), [includedGame.id])
        })

        try await app.test(.GET, "api/v1/games?family_id_search=\(familyId.uuidString)&page=0&per_page=10&sort_by=name&asc=1", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminLogin.token.sessionId)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let games = try res.content.decode([GameMeta].self)
            XCTAssertEqual(games.map(\.id), [includedGame.id])
            XCTAssertFalse(games.contains(where: { $0.id == excludedGame.id }))
        })

        try await app.test(.GET, "api/v1/user/\(adminSession.user.uuidString)/profile/\(profile.id.uuidString)/games?family_id_search=\(familyId.uuidString)&page=0&per_page=10&sort_by=name&asc=1", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminLogin.token.sessionId)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let games = try res.content.decode([GameMeta].self)
            XCTAssertEqual(games.map(\.id), [includedGame.id])
            XCTAssertFalse(games.contains(where: { $0.id == excludedGame.id }))
        })
    }

    func testAPIDeleteGameReplaceWithParentAndAllowBreak() async throws {
        _ = try await registerUser(
            username: "games-delete-admin",
            email: "games-delete-admin@example.com",
            password: "password123"
        )
        let adminLogin = try await loginUser(
            username: "games-delete-admin",
            password: "password123"
        )
        let familyId = UUID()
        let parentGame = try insertGameMeta(name: "Parent Game", familyId: familyId)
        let childGame = try insertGameMeta(name: "Child Game", familyId: familyId, baseGameId: parentGame.id)
        let dependentHash = try insertGameHash(gameMetaId: childGame.id, hash: "replace-child-hash")
        let adminSession = try await currentSession(for: adminLogin.token.sessionId)
        let profile = try insertProfile(userId: adminSession.user, name: "Delete Profile")
        let save = try insertSave(
            userId: adminSession.user,
            profileId: profile.id,
            gameHashId: dependentHash.id,
            gameMetaId: childGame.id,
            name: "Child Save"
        )

        try await app.test(.DELETE, "api/v1/games/\(childGame.id.uuidString)?replace_with_parent=1&allow_break=1", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminLogin.token.sessionId)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
        })

        let savedState = try await DBShared.pool().read { db in
            let deletedChild = try GameMeta.filter(id: childGame.id).fetchOne(db)
            let updatedHash = try GameHash.filter(id: dependentHash.id).fetchOne(db)
            let updatedSave = try Save.filter(id: save.id).fetchOne(db)
            return (deletedChild, updatedHash, updatedSave)
        }
        XCTAssertNil(savedState.0)
        XCTAssertEqual(savedState.1?.gameMetaId, parentGame.id)
        XCTAssertEqual(savedState.2?.gameMetaId, parentGame.id)
    }


    func testAPIUserProfileRoutesWorkThroughPathVariants() async throws {
        _ = try await registerUser(
            username: "profiles-admin",
            email: "profiles-admin@example.com",
            password: "password123"
        )
        let adminLogin = try await loginUser(
            username: "profiles-admin",
            password: "password123"
        )

        var createdProfile: UserProfile?
        try await app.test(.POST, "api/v1/user/profile", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminLogin.token.sessionId)
            try req.content.encode(PostUserProfile(id: nil, name: "Primary Profile"))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            createdProfile = try res.content.decode(UserProfile.self)
        })

        let profile = try XCTUnwrap(createdProfile)
        let adminSession = try await currentSession(for: adminLogin.token.sessionId)

        try await app.test(.GET, "api/v1/user/\(adminSession.user.uuidString)/profile", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminLogin.token.sessionId)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let profiles = try res.content.decode([UserProfile].self)
            XCTAssertTrue(profiles.contains(where: { $0.id == profile.id }))
        })

        try await app.test(.PUT, "api/v1/user/\(adminSession.user.uuidString)/profile/\(profile.id.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminLogin.token.sessionId)
            try req.content.encode(PutUserProfile(id: nil, name: "Renamed Profile"))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let updatedProfile = try res.content.decode(UserProfile.self)
            XCTAssertEqual(updatedProfile.id, profile.id)
            XCTAssertEqual(updatedProfile.name, "Renamed Profile")
        })

        try await app.test(.DELETE, "api/v1/user/profile/\(profile.id.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminLogin.token.sessionId)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
        })

        let deletedProfile = try await DBShared.pool().read { db in
            try UserProfile.filter(id: profile.id).fetchOne(db)
        }
        XCTAssertNil(deletedProfile)
    }

    func testAPISaveRoutesWorkForListGetAndDelete() async throws {
        _ = try await registerUser(
            username: "saves-admin",
            email: "saves-admin@example.com",
            password: "password123"
        )
        let adminLogin = try await loginUser(
            username: "saves-admin",
            password: "password123"
        )
        let adminSession = try await currentSession(for: adminLogin.token.sessionId)
        let profile = try insertProfile(userId: adminSession.user, name: "Save Profile")
        let game = try insertGameMeta(name: "Seeded Game")
        let hash = try insertGameHash(gameMetaId: game.id, hash: "hash-save-1")
        let save = try insertSave(
            userId: adminSession.user,
            profileId: profile.id,
            gameHashId: hash.id,
            gameMetaId: game.id,
            name: "First Save"
        )
        _ = try insertSave(
            userId: adminSession.user,
            profileId: profile.id,
            gameHashId: hash.id,
            gameMetaId: game.id,
            name: "Second Save"
        )

        try await app.test(.GET, "api/v1/user/\(adminSession.user.uuidString)/profile/\(profile.id.uuidString)/games", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminLogin.token.sessionId)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let games = try res.content.decode([GameMeta].self)
            XCTAssertTrue(games.contains(where: { $0.id == game.id }))
        })

        try await app.test(.GET, "api/v1/user/\(adminSession.user.uuidString)/profile/\(profile.id.uuidString)/games/\(game.id.uuidString)/saves", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminLogin.token.sessionId)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let saves = try res.content.decode([Save].self)
            XCTAssertEqual(saves.count, 2)
            XCTAssertTrue(saves.contains(where: { $0.id == save.id }))
        })

        try await app.test(.GET, "api/v1/save/\(save.id.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminLogin.token.sessionId)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let fetchedSave = try res.content.decode(Save.self)
            XCTAssertEqual(fetchedSave.id, save.id)
            XCTAssertEqual(fetchedSave.userId, adminSession.user)
        })

        try await app.test(.DELETE, "api/v1/save/\(save.id.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminLogin.token.sessionId)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
        })

        try await app.test(.DELETE, "api/v1/user/\(adminSession.user.uuidString)/profile/\(profile.id.uuidString)/games/\(game.id.uuidString)/saves", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: adminLogin.token.sessionId)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
        })

        let remainingSaves = try await DBShared.pool().read { db in
            try Save.filter(Column("profile_id") == profile.id).fetchCount(db)
        }
        XCTAssertEqual(remainingSaves, 0)
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

    private func currentSession(for sessionId: String) async throws -> AuthSession {
        let uuid = try XCTUnwrap(UUID(uuidString: sessionId))
        let session = try await DBShared.pool().read { db in
            try AuthSession.filter(id: uuid).fetchOne(db)
        }
        return try XCTUnwrap(session)
    }

    private func insertProfile(userId: UUID, name: String) throws -> UserProfile {
        let now = Date()
        var profile = UserProfile(
            id: UUID(),
            userId: userId,
            name: name,
            createdAt: now,
            updatedAt: now
        )
        try DBShared.pool().write { db in
            try profile.insert(db)
        }
        return profile
    }

    private func insertGameMeta(name: String, familyId: UUID? = nil, baseGameId: UUID? = nil) throws -> GameMeta {
        let now = Date()
        var game = GameMeta(
            id: UUID(),
            familyId: familyId,
            baseGameId: baseGameId,
            name: name,
            version: "1.0",
            breaksSaveFormatFromPreviousVersion: false,
            breaksSaveFormatFromBaseGame: false,
            createdAt: now,
            updatedAt: now
        )
        try DBShared.pool().write { db in
            try game.insert(db)
        }
        return game
    }

    private func insertGameHash(gameMetaId: UUID, hash: String) throws -> GameHash {
        let now = Date()
        var gameHash = GameHash(
            id: UUID(),
            gameMetaId: gameMetaId,
            hashedFileName: "game.exe",
            xxhash64: hash,
            createdAt: now,
            updatedAt: now
        )
        try DBShared.pool().write { db in
            try gameHash.insert(db)
        }
        return gameHash
    }

    private func insertSave(userId: UUID, profileId: UUID, gameHashId: UUID, gameMetaId: UUID, name: String) throws -> Save {
        let now = Date()
        let compatibilityId = UUID()
        var compatibility = Compatibility(id: compatibilityId, updatedAt: now)
        try DBShared.pool().write { db in
            try compatibility.insert(db)
        }
        var save = Save(
            id: UUID(),
            gameHashId: gameHashId,
            gameMetaId: gameMetaId,
            compatibilityId: compatibilityId,
            sequentialId: UUID(),
            profileId: profileId,
            userId: userId,
            url: "https://example.com/\(UUID().uuidString).zip",
            fileSize: 1024,
            sourceDevice: "tests",
            name: name,
            contentHash: "content-\(UUID().uuidString)",
            notes: "test save",
            date: now,
            createdAt: now,
            updatedAt: now
        )
        try DBShared.pool().write { db in
            try save.insert(db)
        }
        return save
    }
}
