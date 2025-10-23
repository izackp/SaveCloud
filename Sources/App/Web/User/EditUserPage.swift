//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/23/24.
//

import Vapor
import HRW

struct EditUserPage {
    let binding:EditUserPageBinding
    let rootNode:Html
    
    public init(_ app:Application, user:User, userEditError:String?, passwordEditError:String?) throws {
        let nodes = try app.readHtmlFromFile("EditUserPage.html")
        let rootNode = nodes.first as! Html
        binding = try EditUserPageBinding(rootNode: rootNode)
        self.rootNode = rootNode
        
        binding.nav_bar.addChild(try NavBar(app, isAdmin:user.isAdmin).rootNode)
        binding.edit_user_form.addChild(try EditUserForm(app, user:user, error:userEditError).rootNode)
        binding.change_password_form.addChild(try ChangePasswordForm(app, error:passwordEditError).rootNode)
    }
}
