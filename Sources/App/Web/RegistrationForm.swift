//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/15/24.
//

import Foundation
import Plot
import Vapor
import Argon2Swift

struct RegisterRequest: Content {
    let username: String
    let email: String
    let password: String
    let password_confirmation: String
}

struct RegisterForm: Plot.Component, IHtmlHeader {
    func header() -> String {
        "Registration"
    }
    
    func css() -> String {
        "/style.css"
    }
    
    public init(error: String? = nil) {
        self.error = error
    }
    
    let error:String?
    
    var body: Component {
        Div() {
            Form(url: "/register", method: HTMLFormMethod.post, contentType: HTMLFormContentType.urlEncoded) {
                FieldSet {
                    Label("Username") {
                        TextField(name: "username", isRequired: true)
                            .autoFocused()
                            .autoComplete(false)
                    }
                    Label("Email") {
                        TextField(name: "email", isRequired: true)
                    }
                    Label("Password") {
                        PasswordInput()
                            .class("password-input")
                    }
                    .class("password-label")
                    Label("Re-enter Password") {
                        PasswordInput(name:"password_confirmation")
                            .class("password-input")
                    }
                    .class("password-label")
                    SubmitButton("Register")
                }
            }
            if let error = error {
                Paragraph(error)
            }
        }.class("content")
    }
}


@Sendable func register(req: Request) async throws -> Response {//EventLoopFuture<AuthSession> {
    let contents = try req.content.decode(RegisterRequest.self)
    var errors = [String]()
    //var usernameError = false
    //var passwordError = false
    if contents.email.count == 0  {
        errors.append("You must supply your username")
        //usernameError = true
    }
    if contents.password.count == 0 {
        errors.append("You must supply your password")
        //passwordError = true
    }
    if contents.password != contents.password_confirmation {
        errors.append("Passwords do not match")
        //passwordError = true
    }
    if !errors.isEmpty {
        let response = RegisterForm(error: errors.joined(separator: "\n")).wrapHTML()
        return response.response()
        //throw Abort(.unauthorized)
        //return some view
    }
    
    let salt = Salt.newSalt()
    let passwordHash = try Argon2Swift.hashPasswordString(password: contents.password, salt: salt)
    
    let connection = try Database.getConnection()
    let numUsers = try connection.count(User.self)
    let isAdmin = numUsers == 0
    let date = Date()
    let newUser = User(id: UUID.init(), username:contents.username, email: contents.email, passwordHash: passwordHash.encodedString(), isAdmin: isAdmin, createdAt: date, updatedAt: date)
    
    try connection.insert(User.self, item: newUser)
    
    //TODO: Build with SEC-CH-UA-PLATFORM etc
    let userAgent = req.headers.first(name: .userAgent)
    //TODO: Add ip address field
    let ipAddress = req.remoteAddress?.ipAddress ?? ""
    //TODO: Odd if empty
    
    let expirationDate = date.advanced(by: 24 * 60 * 60)
    let newSession = AuthSession(id: UUID.init(), refreshToken: UUID.init(), user: newUser.id, deviceName: userAgent, location: nil, ipAddress: ipAddress, isAdmin: isAdmin, createdAt: date, updatedAt: date, expiresAt: expirationDate)
    try connection.insert(AuthSession.self, item: newSession)
    
    req.session.authenticate(newSession)
    
    return req.redirect(to: "/", redirectType: .normal)
}
