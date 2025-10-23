//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/23/24.
//

import Vapor
import HRW

struct WelcomePage {
    let binding:WelcomePageBinding
    let rootNode:Html
    
    public init(_ app:Application, users: [User], error:String?) throws {
        let nodes = try app.readHtmlFromFile("WelcomePage.html")
        let rootNode = nodes.first as! Html
        binding = try WelcomePageBinding(rootNode:rootNode)
        self.rootNode = rootNode
        if let error = error {
            binding.p_error.addChild(HTMLText(content: error))
            binding.p_error.globalAttributes[.style] = ""
        }
        for eachUser in users {
            binding.table.children.append(try WelcomeTableRow(app, user:eachUser).rootNode)
        }
    }
}
