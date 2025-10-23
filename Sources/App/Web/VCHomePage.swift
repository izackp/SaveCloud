//
//  HomePage.swift
//  
//
//  Created by Isaac Paul on 5/23/24.
//

import Vapor
import HRW

struct HomePage {
    let binding:HomePageBinding
    let rootNode:Html
    
    public init(_ app:Application, isAdmin:Bool) throws {
        let nodes = try app.readHtmlFromFile("HomePage.html")
        let rootNode = nodes.first as! Html
        binding = try HomePageBinding(rootNode: rootNode)
        self.rootNode = rootNode
        
        binding.nav_bar.addChild(try NavBar(app, isAdmin: isAdmin).rootNode)
    }
}
