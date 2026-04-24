//
//  routes.swift
//
//
//  Created by Isaac Paul on 5/15/24.
//

import Vapor
import Argon2Swift
import HRW

func internalError() -> Html {
    let page = try! Html.init([:])
    let body = try! Body([:])
    let text = HTMLText(content: "Internal Error")
    body.addChild(text)
    page.children.append(body)
    return page
}

func routes(_ app: Application) throws {
    app.get { req async throws in
        let session = try? await req.fetchSession() //TODO: Log error
        if let session = session {
            return try VCHomePage(isAdmin: session.isAdmin).rootNode
        } else {
            do {
                let pool = DBShared.pool()
                let users = try await pool.read { db in
                    try User.fetchAll(db)
                }
                return try VCWelcomePage(users: users, error: nil).rootNode
            } catch {
                
                return try VCWelcomePage(users: [], error: nil).rootNode
            }
        }
    }
    /*
    app.get { req async throws in
        let session = try? req.fetchSession() //TODO: Log error
        if let session = session {
            return try HomePage(app, isAdmin: session.isAdmin).rootNode
        } else {
            do {
                let pool = DBShared.pool()
                let users = try pool.fetchAll(User.self)
                return try WelcomePage(app, users: users, error: nil).rootNode
            } catch {
                return try WelcomePage(app, users: [], error: nil).rootNode
            }
        }
    }
    */
    app.get("register") { req async throws in
        try VCRegistrationForm().rootNode
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
        let pool = DBShared.pool()
        let result: (AuthSession?, User?) = try await pool.read { db in
            guard let session = try req.fetchSession(db) else {
                return (nil, nil)
            }
            if let user = try User.filter(id: session.user).fetchOne(db) {
                return (session, user)
            } else {
                return (session, nil)
            }
        }
        let (session, user) = result
        guard session != nil else {
            return try VCWelcomePage(users:[], error:"Session doesn't exist").rootNode.response()
        }
        guard let user = user else {
            return try VCWelcomePage(users:[], error:"User not found").rootNode.response()
        }
        return try VCEditUserPage(user: user, userEditError: nil, passwordEditError: nil).rootNode.response()
    }
    
}


func signOut(
    _ req: Request
) throws -> Response {
    req.session.unauthenticate(AuthenticatedUser.self)
    return req.redirect(to: "/")
}
