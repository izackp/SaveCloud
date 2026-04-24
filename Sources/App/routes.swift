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
    app.post("api", "v1", "login", use: apiLoginSession(req:))
    
    let apiAuth = app.routes.grouped([
        APISessionAuthenticator(), AuthSession.guardMiddleware()
    ])
    apiAuth.get("api", "v1", "user", use: apiGETUser(req:))
    apiAuth.get("api", "v1", "user", ":user_id", use: apiGETUser(req:))
    apiAuth.put("api", "v1", "user", use: apiPUTUser(req:))
    apiAuth.put("api", "v1", "user", ":user_id", use: apiPUTUser(req:))
    apiAuth.delete("api", "v1", "user", use: apiDELETEUser(req:))
    apiAuth.delete("api", "v1", "user", ":user_id", use: apiDELETEUser(req:))
    apiAuth.get("api", "v1", "games", use: apiGETGameList(req:))
    apiAuth.get("api", "v1", "games", "by_family", ":family_id", use: apiGETGameList(req:))
    apiAuth.get("api", "v1", "games", ":game_id", use: apiGETGame(req:))
    apiAuth.post("api", "v1", "games", use: apiPOSTGame(req:))
    apiAuth.put("api", "v1", "games", ":game_id", use: apiPUTGame(req:))
    apiAuth.delete("api", "v1", "games", ":game_id") { req async throws -> HTTPStatus in
        try await apiDELETEGame(req: req)
        return .ok
    }
    apiAuth.get("api", "v1", "user", "profile", use: apiGETUserProfiles(req:))
    apiAuth.get("api", "v1", "user", ":user_id", "profile", use: apiGETUserProfiles(req:))
    apiAuth.post("api", "v1", "user", "profile", use: apiPOSTUserProfile(req:))
    apiAuth.post("api", "v1", "user", ":user_id", "profile", use: apiPOSTUserProfile(req:))
    apiAuth.put("api", "v1", "user", "profile", ":profile_id", use: apiPUTUserProfile(req:))
    apiAuth.put("api", "v1", "user", ":user_id", "profile", ":profile_id", use: apiPUTUserProfile(req:))
    apiAuth.delete("api", "v1", "user", "profile", ":profile_id") { req async throws -> HTTPStatus in
        try await apiDELETEUserProfile(req: req)
        return .ok
    }
    apiAuth.delete("api", "v1", "user", ":user_id", "profile", ":profile_id") { req async throws -> HTTPStatus in
        try await apiDELETEUserProfile(req: req)
        return .ok
    }
    apiAuth.get("api", "v1", "user", "profile", ":profile_id", "games", use: apiGETGameList(req:))
    apiAuth.get("api", "v1", "user", ":user_id", "profile", ":profile_id", "games", use: apiGETGameList(req:))
    apiAuth.get("api", "v1", "user", "profile", ":profile_id", "saves", use: apiGETSaves(req:))
    apiAuth.get("api", "v1", "user", ":user_id", "profile", ":profile_id", "saves", use: apiGETSaves(req:))
    apiAuth.delete("api", "v1", "user", "profile", ":profile_id", "saves") { req async throws -> HTTPStatus in
        try await apiDELETESaves(req: req)
        return .ok
    }
    apiAuth.delete("api", "v1", "user", ":user_id", "profile", ":profile_id", "saves") { req async throws -> HTTPStatus in
        try await apiDELETESaves(req: req)
        return .ok
    }
    apiAuth.get("api", "v1", "user", "profile", ":profile_id", "games", ":game_meta_id", "saves", use: apiGETSaves(req:))
    apiAuth.get("api", "v1", "user", ":user_id", "profile", ":profile_id", "games", ":game_meta_id", "saves", use: apiGETSaves(req:))
    apiAuth.delete("api", "v1", "user", "profile", ":profile_id", "games", ":game_meta_id", "saves") { req async throws -> HTTPStatus in
        try await apiDELETESaves(req: req)
        return .ok
    }
    apiAuth.delete("api", "v1", "user", ":user_id", "profile", ":profile_id", "games", ":game_meta_id", "saves") { req async throws -> HTTPStatus in
        try await apiDELETESaves(req: req)
        return .ok
    }
    apiAuth.get("api", "v1", "save", ":save_id", use: apiGETSave(req:))
    apiAuth.delete("api", "v1", "save", ":save_id") { req async throws -> HTTPStatus in
        try await apiDELETESave(req: req)
        return .ok
    }

    let userSessGroup = app.routes
    userSessGroup.post("login", use: login(req:))
    userSessGroup.post("user", "edit", use: editUser(req:))
    userSessGroup.post("user", "change_password", use: changePassword(req:))
    userSessGroup.get("user", "edit_all", use: editAllUsers(req:))
    userSessGroup.get("user", "edit_all", "new", use: newManagedUserPage(req:))
    userSessGroup.post("user", "edit_all", "new", use: createManagedUser(req:))
    userSessGroup.get("user", "edit_all", ":managed_user_id", "edit", use: editManagedUserPage(req:))
    userSessGroup.post("user", "edit_all", ":managed_user_id", "edit", use: updateManagedUser(req:))
    userSessGroup.get("user", "edit_all", ":managed_user_id", "delete", use: deleteManagedUserPage(req:))
    userSessGroup.post("user", "edit_all", ":managed_user_id", "delete", use: deleteManagedUser(req:))
    userSessGroup.get("user", "sessions", use: editAllSessions(req:))
    userSessGroup.get("user", "sessions", ":managed_session_id", "edit", use: editManagedSessionPage(req:))
    userSessGroup.post("user", "sessions", ":managed_session_id", "edit", use: updateManagedSession(req:))
    userSessGroup.get("user", "sessions", ":managed_session_id", "delete", use: deleteManagedSessionPage(req:))
    userSessGroup.post("user", "sessions", ":managed_session_id", "delete", use: deleteManagedSession(req:))
    userSessGroup.get("users", ":user_id", "sessions", use: editAllSessions(req:))
    userSessGroup.get("users", ":user_id", "sessions", ":managed_session_id", "edit", use: editManagedSessionPage(req:))
    userSessGroup.post("users", ":user_id", "sessions", ":managed_session_id", "edit", use: updateManagedSession(req:))
    userSessGroup.get("users", ":user_id", "sessions", ":managed_session_id", "delete", use: deleteManagedSessionPage(req:))
    userSessGroup.post("users", ":user_id", "sessions", ":managed_session_id", "delete", use: deleteManagedSession(req:))
    userSessGroup.get("sessions", use: editAllSessions(req:))
    userSessGroup.get("sessions", ":managed_session_id", "edit", use: editManagedSessionPage(req:))
    userSessGroup.post("sessions", ":managed_session_id", "edit", use: updateManagedSession(req:))
    userSessGroup.get("sessions", ":managed_session_id", "delete", use: deleteManagedSessionPage(req:))
    userSessGroup.post("sessions", ":managed_session_id", "delete", use: deleteManagedSession(req:))
    
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
    let response = req.redirect(to: "/")
    clearBrowserSessionCookie(on: response)
    return response
}
