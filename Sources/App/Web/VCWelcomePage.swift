//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/23/24.
//

import Vapor
import HRW

class VCWelcomePage : WelcomePage {
    public init(users: [User], error:String?) throws {
        try super.init()
        let loginForm = try LoginForm().rootNode
        self.login_form.addChild(loginForm)
        if let error = error {
            p_error.addChild(HTMLText(content: error))
            p_error.globalAttributes[.style] = ""
        }
        for eachUser in users {
            table.children.append(try VCWelcomeTableRow(user:eachUser).rootNode)
        }
    }
}
