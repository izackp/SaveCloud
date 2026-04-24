//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/14/24.
//

import Foundation
import Vapor
import Argon2Swift
import GRDB

public let hours24:TimeInterval = 24 * 60 * 60
public let apiSessionDuration: TimeInterval = 365 * hours24
public let apiSessionRenewWindow: TimeInterval = apiSessionDuration - hours24

struct APISessionAuthenticator: AsyncBearerAuthenticator {

    func authenticate(
        bearer: BearerAuthorization,
        for request: Request
    ) async throws {
        guard let sessionId = UUID(uuidString: bearer.token) else {
            return
        }
        
        let pool = DBShared.pool()
        guard let session = try await pool.read({ db in
            try AuthSession.filter(id: sessionId).fetchOne(db)
        }) else {
            return
        }
        if session.isExpired() {
            _ = try await pool.write { db in
                try AuthSession.filter(id: sessionId).deleteAll(db)
            }
            throw Abort(.unauthorized, reason: "Session expired")
        }
        if session.expiresAt < Date().advanced(by: apiSessionRenewWindow) {
            let newExpirationDate = Date().advanced(by: apiSessionDuration)
            try await pool.write { db in
                _ = try AuthSession
                    .filter(id: sessionId)
                    .updateAll(
                        db,
                        AuthSession.expires_at.set(to: newExpirationDate),
                        AuthSession.updated_at.set(to: Date())
                    )
            }
        }
        
        request.auth.login(session)
    }
}

struct UserSessionAuthenticator: AsyncSessionAuthenticator {
    typealias User = AuthenticatedUser

    func authenticate(
        sessionID: AuthenticatedUser.SessionID,
        for req: Request
    ) async throws {
        
        let pool = DBShared.pool()
        guard let session = try await pool.read({ db in
            try AuthSession.filter(id: sessionID).fetchOne(db)
        }) else {
            return
        }
        //req.auth.login(session)
        req.session.authenticate(session)
    }
}


struct UserCredentialsAuthenticator: AsyncCredentialsAuthenticator {
    
    struct Credentials: Content {
        let email_or_username: String
        let password: String
        
        func validate() throws {
            if email_or_username.count == 0  {
                throw Abort(.badRequest)
            }
            if password.count == 0 {
                throw Abort(.badRequest)
            }
        }
    }
    
    func authenticate(
        credentials: Credentials,
        for req: Request
    ) async throws {
        try credentials.validate()
        
        let pool = DBShared.pool()
        guard let user = try await User.first(emailOrUsername: credentials.email_or_username, pool) else {
            throw Abort(.notFound)
        }
        
        let verified = try Argon2Swift.verifyHashString(password: credentials.password, hash: user.passwordHash ?? "")
        if (!verified) {
            throw Abort(.unauthorized) //AppError("Wrong Password") {"reason":"App.AppError","error":true}
        }
        let hours24:TimeInterval = 24 * 60 * 60
        let newSession = try await createSession(req, user.id, user.isAdmin, hours24, nil, pool)
        
        req.session.authenticate(newSession)
    }
}

func createSession(_ req: Request, _ userId:UUID, _ isAdmin:Bool, _ expiresIn:TimeInterval = hours24, _ refreshToken:UUID?) async throws -> AuthSession {
    let pool = DBShared.pool()
    return try await createSession(req, userId, isAdmin, expiresIn, refreshToken, pool)
}

func createSession(_ req: Request, _ userId:UUID, _ isAdmin:Bool, _ expiresIn:TimeInterval = hours24, _ refreshToken:UUID?, _ pool:DatabasePool) async throws -> AuthSession {
    //TODO: Build with SEC-CH-UA-PLATFORM etc
    let userAgent = req.headers.first(name: .userAgent)
    //TODO: Add ip address field
    let ipAddress = req.remoteAddress?.ipAddress ?? "" //TODO: Odd if empty
    
    let date = Date()
    let expirationDate:Date = date.advanced(by: expiresIn)
    let newSession = AuthSession(id: UUID.init(), refreshToken: refreshToken, user: userId, deviceName: userAgent, location: nil, ipAddress: ipAddress, isAdmin: isAdmin, createdAt: date, updatedAt: date, expiresAt: expirationDate)
    return try await pool.write { db in
        var session = newSession
        try session.insert(db)
        return session
    }
}
