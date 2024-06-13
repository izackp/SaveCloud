//
//  routes.swift
//
//
//  Created by Isaac Paul on 5/15/24.
//

import Vapor
import Argon2Swift
import Plot

func routes(_ app: Application) throws {
    app.get { req async in
        let session = try? req.fetchSession() //TODO: Log error
        if let session = session {
            return HomePage(admin: session.isAdmin).wrapHTML()
        } else {
            do {
                let connection = try Database.getConnection()
                let users = try connection.fetchAll(User.self)
                return WelcomePage(error: nil, users: users).wrapHTML()
            } catch {
                
                return WelcomePage(error: nil).wrapHTML()
            }
        }
    }
    
    app.get { req async in
        let session = try? req.fetchSession() //TODO: Log error
        if let session = session {
            return HomePage(admin: session.isAdmin).wrapHTML()
        } else {
            do {
                let connection = try Database.getConnection()
                let users = try connection.fetchAll(User.self)
                return WelcomePage(error: nil, users: users).wrapHTML()
            } catch {
                
                return WelcomePage(error: nil).wrapHTML()
            }
        }
    }
    app.get("register") { req async in
        RegisterForm().wrapHTML()
    }

    app.post("register", use: register(req:))
    app.post("api", "v1", "register", use: apiRegister(req:))
    app.post("api", "v1", "login", use: apiLoginJWT(req:))
    app.post("api", "v1", "refresh", use: apiRefreshJWT(req:))
    
    let jwtAuth = app.routes.grouped([
        JWTClaimAuthenticator(), JWTClaims.guardMiddleware()
    ])
    jwtAuth.get("api", "v1", "user", use: apiGETUser(req:))
    jwtAuth.get("api", "v1", "user", ":id", use: apiGETUser(req:))
    jwtAuth.put("api", "v1", "user", use: apiPUTUser(req:))
    jwtAuth.put("api", "v1", "user", ":id", use: apiPUTUser(req:))
    jwtAuth.delete("api", "v1", "user", use: apiDELETEUser(req:))
    jwtAuth.delete("api", "v1", "user", ":id", use: apiDELETEUser(req:))

    let userSessGroup = app.routes.grouped([
        UserSessionAuthenticator(),
    ])
    userSessGroup.post("login", use: login(req:))
    userSessGroup.post("user", "edit", use: editUser(req:))
    userSessGroup.post("user", "change_password", use: changePassword(req:))
    
    userSessGroup.get("user", "edit") { req async throws in
        let connection = try Database.getConnection()
        guard
            let session = try req.fetchSession(),
            let user = try connection.first(User.self, uuid:session.user) else {//TODO: Log error
            return WelcomePage(error:"Session doesn't exist").wrapHTML().response()
        }
        return EditUserPage(user: user, userEditError: nil, passwordEditError: nil).wrapHTML().response()
    }
    
}


func signOut(
    _ req: Request
) throws -> Response {
    req.session.unauthenticate(AuthenticatedUser.self)
    return req.redirect(to: "/")
}

