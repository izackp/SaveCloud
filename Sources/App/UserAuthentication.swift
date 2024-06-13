//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/14/24.
//

import Foundation
import Vapor
import Argon2Swift
import SQLite
import SwiftJWT

struct JWTClaimAuthenticator: AsyncBearerAuthenticator {

    func authenticate(
        bearer: BearerAuthorization,
        for request: Request
    ) async throws {
        
        let jwtVerifier = JWTVerifier.rs256(publicKey: jwtPublicKey)
        let jwt = try JWT<JWTClaims>(jwtString: bearer.token, verifier: jwtVerifier)
        if (jwt.validateClaims(leeway: 60) == .success) {
            request.auth.login(jwt.claims)
            return
        }
        //throw Abort(.unauthorized)
    }
}

struct UserSessionAuthenticator: AsyncSessionAuthenticator {
    typealias User = AuthenticatedUser

    func authenticate(
        sessionID: AuthenticatedUser.SessionID,
        for req: Request
    ) async throws {
        
        let connection = try Database.getConnection()
        guard let session = try TBLSession.first(connection, uuid: sessionID) else {
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
        
        let connection = try Database.getConnection()
        guard let user = try TblUser.first(connection, emailOrUsername: credentials.email_or_username) else {
            throw Abort(.notFound)
        }
        
        let verified = try Argon2Swift.verifyHashString(password: credentials.password, hash: user.passwordHash ?? "")
        if (!verified) {
            throw Abort(.unauthorized) //AppError("Wrong Password") {"reason":"App.AppError","error":true}
        }
        let hours24:TimeInterval = 24 * 60 * 60
        let newSession = try createSession(req, user.id, user.isAdmin, hours24, nil, connection)
        
        req.session.authenticate(newSession)
    }
}

public let hours24:TimeInterval = 24 * 60 * 60

func createSession(_ req: Request, _ userId:UUID, _ isAdmin:Bool, _ expiresIn:TimeInterval = hours24, _ refreshToken:UUID?) throws -> AuthSession {
    let connection = try Database.getConnection()
    return try createSession(req, userId, isAdmin, expiresIn, refreshToken, connection)
}

func createSession(_ req: Request, _ userId:UUID, _ isAdmin:Bool, _ expiresIn:TimeInterval = hours24, _ refreshToken:UUID?, _ connection:Connection) throws -> AuthSession {
    //TODO: Build with SEC-CH-UA-PLATFORM etc
    let userAgent = req.headers.first(name: .userAgent)
    //TODO: Add ip address field
    let ipAddress = req.remoteAddress?.ipAddress ?? "" //TODO: Odd if empty
    
    let date = Date()
    let expirationDate:Date = date.advanced(by: expiresIn)
    let newSession = AuthSession(id: UUID.init(), refreshToken: refreshToken, user: userId, deviceName: userAgent, location: nil, ipAddress: ipAddress, isAdmin: isAdmin, createdAt: date, updatedAt: date, expiresAt: expirationDate)
    try connection.insert(AuthSession.self, item: newSession)
    return newSession
}
