//
//  WelcomeTableRow.swift
//  SaveCloud
//
//  Created by Isaac Paul on 10/8/25.
//

import Vapor
import HRW

struct WelcomeTableRow {
    let binding:WelcomeTableRowBinding
    let rootNode:Tr
    
    public init(_ app:Application, user: User) throws {
        let nodes = try app.readHtmlFromFile("WelcomeTableRow.html")
        let rootNode = nodes.first as! Tr
        binding = try WelcomeTableRowBinding(rootNode: rootNode)
        self.rootNode = rootNode
        binding.user_id.addChild(HTMLText(content: user.id.uuidString))
        binding.username.addChild(HTMLText(content: user.username))
        binding.email.addChild(HTMLText(content: user.email ?? ""))
        binding.password_hash.addChild(HTMLText(content: user.passwordHash ?? ""))
        binding.created_at.addChild(HTMLText(content: String(describing: user.createdAt)))
        binding.updated_at.addChild(HTMLText(content: String(describing: user.updatedAt)))
    }
}
