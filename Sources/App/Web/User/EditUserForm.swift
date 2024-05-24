//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/23/24.
//

import Plot
import Vapor
import Argon2Swift

struct EditUserRequest: Content {
    let username: String
    let email: String
    let password: String
    
    func validate() -> String? {
        if (username.isEmpty) {
            return "Username is empty."
        }
        if (email.isEmpty) {
            return "Email is empty."
        }
        if (password.isEmpty) {
            return "Password is empty."
        }
        
        return nil
    }
}

struct EditUserForm: Plot.Component {
    let user:User
    let error:String?
    var body: Component {
        Form(url: "/user/edit", method: HTMLFormMethod.post, contentType: HTMLFormContentType.urlEncoded) {
            FieldSet {
                H2("Edit User:")
                Label("Username:") {
                    TextField(name: "username", text: user.username, isRequired: true)
                        .autoFocused()
                        .autoComplete(false)
                }
                Label("Email:") {
                    TextField(name: "email", text: user.email ?? "", isRequired: true)
                }
                if let passwordHash = user.passwordHash {
                    Label("Password:") {
                        Node.br()
                        Text(passwordHash)
                    }
                }
                Label("Created At:") {
                    Node.br()
                    Text(String(describing:user.createdAt))
                }
                Label("Updated At:") {
                    Node.br()
                    Text(String(describing:user.updatedAt))
                }
                Label("Password required to update:") {
                    PasswordInput()
                        .class("password-input")
                }
                if let error = error {
                    Label("Error:") {
                        Node.br()
                        Text(error)
                    }
                }
                SubmitButton("Update")
            }
        }
    }
}

extension Request {
    func fetchSession() throws -> AuthSession? {
        guard let sessionId = session.authenticated(AuthSession.self) else { return nil }
        let connection = try Database.getConnection()
        let session = try connection.first(AuthSession.self, uuid:sessionId)
        return session
    }
}

@Sendable func editUser(req: Request) async throws -> Response {
    let connection = try Database.getConnection()
    guard
        let session = try req.fetchSession(),
        let user = try connection.first(User.self, uuid:session.user) else {
        return WelcomePage(error:"Session doesn't exist").wrapHTML().response()
    }
    
    let contents = try req.content.decode(EditUserRequest.self)
    let error = contents.validate()
    if let error = error {
        let response = EditUserPage(user: user, userEditError: error, passwordEditError: nil).wrapHTML()
        return response.response()
    }
    
    let verified = try Argon2Swift.verifyHashString(password: contents.password, hash: user.passwordHash ?? "")
    if (!verified) {
        return EditUserPage(user: user, userEditError: nil, passwordEditError: "Password is incorrect.").wrapHTML().response()
    }
    
    user.email = contents.email
    user.username = contents.username
    user.updatedAt = Date()
    try connection.update(User.self, item:user)
    
    let response = EditUserPage(user: user, userEditError: nil, passwordEditError: nil).wrapHTML()
    return response.response()
}
