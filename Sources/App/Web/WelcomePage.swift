//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/23/24.
//

import Vapor
import Plot

struct WelcomePage: Plot.Component, IHtmlHeader {
    func header() -> String {
        "Save Cloud - Welcome"
    }
    
    func css() -> String {
        "/style.css"
    }
    
    public init(error: String? = nil, users:[User] = []) {
        self.error = error
        self.users = users
    }
    
    let error:String?
    let users:[User]
    
    var body: Component {
        Div {
            H1("Save Cloud")
            LoginForm()
            if let error = error, !error.isEmpty {
                Paragraph(error)
            }
            Link("Register", url: "/register")
            Table() {
                for eachUser in users {
                    TableRow() {
                        TableCell(eachUser.id.uuidString)
                        TableCell(eachUser.username)
                        TableCell(eachUser.email ?? "")
                        TableCell(eachUser.passwordHash ?? "")
                        TableCell(String(describing: eachUser.createdAt))
                        TableCell(String(describing: eachUser.updatedAt))
                    }
                }
            }
        }.class("content")
    }
}
