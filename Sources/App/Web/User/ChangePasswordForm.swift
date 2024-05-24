//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/23/24.
//

import Plot
import Vapor
import Argon2Swift
import SQLite

struct ChangePasswordRequest: Content {
    let password_current: String
    let password: String
    let password_confirmation: String
    
    func validate() -> String? {
        if (password_current.isEmpty) {
            return "Current password is empty."
        }
        if (password.isEmpty) {
            return "New password is empty."
        }
        
        return nil
    }
}

struct ChangePasswordForm: Plot.Component {
    let user:User
    let error:String?
    var body: Component {
        Form(url: "/user/change_password", method: HTMLFormMethod.post, contentType: HTMLFormContentType.urlEncoded) {
            FieldSet {
                H2("Change Password:")
                Label("Current Password") {
                    PasswordInput(name:"password_current")
                        .class("password-input")
                }
                .class("password-label")
                Label("New Password:") {
                    PasswordInput()
                        .class("password-input")
                }
                .class("password-label")
                Label("Re-enter New Password:") {
                    PasswordInput(name:"password_confirmation")
                        .class("password-input")
                }
                .class("password-label")
                if let error = error {
                    Label("Error:") {
                        Node.br()
                        Text(error)
                    }
                }
                SubmitButton("Submit")
            }
        }
    }
}

@Sendable func changePassword(req: Request) async throws -> Response {
    let connection = try Database.getConnection()
    guard
        let session = try req.fetchSession(),
        let user = try connection.first(User.self, uuid:session.user) else {
        return WelcomePage(error:"Session doesn't exist").wrapHTML().response()
    }
    
    let contents = try req.content.decode(ChangePasswordRequest.self)
    let error = contents.validate()
    if let error = error {
        let response = EditUserPage(user: user, userEditError: error, passwordEditError: error).wrapHTML()
        return response.response()
    }
    if (contents.password != contents.password_confirmation) {
        let response = EditUserPage(user: user, userEditError: nil, passwordEditError: "Passwords do not match.").wrapHTML()
        return response.response()
    }
    
    let verified = try Argon2Swift.verifyHashString(password: contents.password_current, hash: user.passwordHash ?? "")
    if (!verified) {
        return EditUserPage(user: user, userEditError: nil, passwordEditError: "Password is incorrect.").wrapHTML().response()
    }
    
    let salt = Salt.newSalt()
    let passwordHash = try Argon2Swift.hashPasswordString(password: contents.password, salt: salt).encodedString()
    
    try connection.updateField(User.self, uuid: user.id, setter: TblUser.passwordHash <- passwordHash)
    
    let response = EditUserPage(user: user, userEditError: nil, passwordEditError: nil).wrapHTML()
    return response.response()
}

