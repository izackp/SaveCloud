//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/23/24.
//

import Vapor
import Plot

struct EditUserPage: Plot.Component, IHtmlHeader {
    func header() -> String {
        return "Edit User"
    }
    
    func css() -> String {
        "/style.css"
    }
    
    let user:User
    let userEditError:String?
    let passwordEditError:String?
    var body: Component {
        Div {
            NavBar(admin: user.isAdmin)
            Div() {
                EditUserForm(user: user, error: userEditError)
                ChangePasswordForm(user: user, error: passwordEditError)
            }.id("nav_body")
        }
    }
}
