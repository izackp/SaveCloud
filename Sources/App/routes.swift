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
        let session = try? req.fetchSession() //TODO: Log error
        if let session = session {
            return try HomePage(app, isAdmin: session.isAdmin).rootNode
        } else {
            do {
                let connection = try Database.getConnection()
                let users = try connection.fetchAll(User.self)
                return try WelcomePage(app, users: users, error: nil).rootNode
            } catch {
                
                return try WelcomePage(app, users: [], error: nil).rootNode
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
                let connection = try Database.getConnection()
                let users = try connection.fetchAll(User.self)
                return try WelcomePage(app, users: users, error: nil).rootNode
            } catch {
                return try WelcomePage(app, users: [], error: nil).rootNode
            }
        }
    }
    */
    app.get("register") { req async throws in
        try RegisterForm(app).rootNode
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
            return try WelcomePage(app, users: [], error:"Session doesn't exist").rootNode.response()
        }
        return try EditUserPage(app, user: user, userEditError: nil, passwordEditError: nil).rootNode.response()
    }
    
}


func signOut(
    _ req: Request
) throws -> Response {
    req.session.unauthenticate(AuthenticatedUser.self)
    return req.redirect(to: "/")
}

