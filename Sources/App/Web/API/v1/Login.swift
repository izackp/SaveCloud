//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/30/24.
//

import Vapor
import Argon2Swift
import SwiftJWT
import SQLite

struct ApiLoginRequest: Content, IValidate {
    let username: String?
    let email: String?
    let password: String
    
    func iterateErrors(_ index:inout Int) -> String? {
        switch index {
            case 0:
                index += 1
                if (email == nil && username == nil) {
                    return "No username or email provided"
                }
                if let email = email, email.isEmpty {
                    return "Email is empty"
                } else if let username = username, username.isEmpty {
                    return "Username is empty"
                }
                fallthrough
            case 1:
                index += 1
                if password.isEmpty {
                    return "Password is empty"
                }
                fallthrough
            default:
                return nil
        }
    }
    
    func emailOrUsername() -> String {
        return username ?? email!
    }
}

struct AuthToken: Content {
    let jwt: String
    let refreshId: String
    let expiresAt: Date
}

struct LoginPair: Content {
    
    init(token: AuthToken, user: PublicUser) {
        self.token = token
        self.user = user
    }
    
    let token: AuthToken
    let user: PublicUser
}

struct JWTClaims: Claims, Authenticatable {
    //let issurer: String //issurer
    let userId: UUID //subject
    let sessionId: UUID //subject
    let expiresAt: Date
    let admin: Bool
}

@Sendable func apiLogin(req: Request) async throws -> PublicUser {
    let contents = try req.content.decode(ApiLoginRequest.self)
    try contents.checkValdiation()
    
    let connection = try Database.getConnection()
    guard let user = try TblUser.first(connection, emailOrUsername: contents.emailOrUsername()) else {
        throw Abort(.notFound, reason: "Username Or Email not found")
    }
    
    let verified = try Argon2Swift.verifyHashString(password: contents.password, hash: user.passwordHash ?? "")
    if (!verified) {
        throw Abort(.unauthorized, reason: "Incorrect password")
    }
    /*
    let newSession = try createSession(req, user.id, user.isAdmin, connection)
    req.session.authenticate(newSession)
    req.auth.login(user)*/
    
    return user.toPublicUser()
}

@Sendable func apiLoginJWT(req: Request) async throws -> LoginPair {
    let user = try await apiLogin(req: req)
    let refreshToken = UUID()
    let newSession = try createSession(req, user.id, user.isAdmin, 365 * 24 * 60 * 60, refreshToken)
    
    let authToken = try generateJWT(userId: user.id, sessionId: newSession.id, refreshToken: refreshToken, admin: user.isAdmin)
    let result = LoginPair(token: authToken, user: user)
    return result
}

func generateJWT(userId: UUID, sessionId: UUID, refreshToken:UUID, admin: Bool) throws -> AuthToken {
    let jwtExpiration = Date().advanced(by: 90 * 60)
    let claims = JWTClaims(userId: userId, sessionId: sessionId, expiresAt: jwtExpiration, admin: admin)
    var myJWT = JWT(header: Header(kid: "SaveCloud1"), claims: claims)
    let jwtSigner = JWTSigner.rs256(privateKey: jwtPrivateKey)
    let signedJWT = try myJWT.sign(using: jwtSigner)
    let authToken = AuthToken(jwt: signedJWT, refreshId: refreshToken.uuidString, expiresAt: jwtExpiration)
    return authToken
}

@Sendable func apiRefreshJWT(req: Request) async throws -> LoginPair {
    guard let auth = req.headers.bearerAuthorization else {
        throw Abort(.unauthorized)
    }
    let contents = try req.content.decode(ApiRefreshRequest.self)
    try contents.checkValdiation()
    
    let jwtVerifier = JWTVerifier.rs256(publicKey: jwtPublicKey)
    let jwt = try JWT<JWTClaims>(jwtString: auth.token, verifier: jwtVerifier)
    let sessionId = jwt.claims.sessionId
    
    let connection = try Database.getConnection()
    guard let session = try TBLSession.first(connection, uuid: sessionId) else {
        throw Abort(.unauthorized)
    }
    if (session.refreshToken == nil) {
        //TODO: Log shananigans
        try connection.delete(AuthSession.self, uuid: sessionId)
        throw Abort(.unauthorized)
    }
    if (session.refreshToken != contents.refreshToken) {
        //TODO: Log shananigans
        try connection.delete(AuthSession.self, uuid: sessionId)
        throw Abort(.unauthorized)
    }
    
    if (session.isExpired()) {
        try connection.delete(AuthSession.self, uuid: sessionId)
        throw Abort(.unauthorized)
    }
    
    guard let user = try connection.first(User.self, uuid: session.user) else {
        //TODO: Log
        throw Abort(.notFound, reason: "User doesnt exist")
    }
    
    let publicUser = user.toPublicUser()
    let newRefreshToken = UUID()
    let newToken = try generateJWT(userId: user.id, sessionId: sessionId, refreshToken: newRefreshToken, admin: user.isAdmin)
    try connection.updateField(AuthSession.self, uuid: sessionId, setter: TBLSession.refreshToken <- newRefreshToken)
    return LoginPair(token: newToken, user: publicUser)
}

struct ApiRefreshRequest: Content, IValidate {
    let refreshToken: UUID
    
    func iterateErrors(_ index:inout Int) -> String? {
        return nil
    }
}
