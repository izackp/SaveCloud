//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/15/24.
//

import Foundation
import Plot
import Vapor

struct LoginRequest: Content {
    let email_or_username: String
    let password: String
    
    func validate() -> String? {
        if (email_or_username.isEmpty) {
            return "Username/email is empty."
        }
        if (password.isEmpty) {
            return "Password is empty."
        }
        
        return nil
    }
}

struct LoginForm: Plot.Component {
    var body: Component {
        Form(url: "/login", method: HTMLFormMethod.post, contentType: HTMLFormContentType.urlEncoded) {
            FieldSet {
                Label("Username or Email") {
                    TextField(name: "email_or_username", isRequired: true)
                        .autoFocused()
                        .autoComplete(false)
                }
                Label("Password") {
                    PasswordInput()
                    .class("password-input")
                }
                .class("password-label")
                SubmitButton("Login")
            }
        }
    }
}
