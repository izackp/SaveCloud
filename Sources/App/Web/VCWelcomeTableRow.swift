//
//  WelcomeTableRow.swift
//  SaveCloud
//
//  Created by Isaac Paul on 10/8/25.
//

import Vapor
import HRW

class VCWelcomeTableRow : WelcomeTableRow {
    public init(user: User) throws {
        try super.init()
        user_id.addChild(HTMLText(content: user.id.uuidString))
        username.addChild(HTMLText(content: user.username))
        email.addChild(HTMLText(content: user.email ?? ""))
        password_hash.addChild(HTMLText(content: user.passwordHash ?? ""))
        created_at.addChild(HTMLText(content: String(describing: user.createdAt)))
        updated_at.addChild(HTMLText(content: String(describing: user.updatedAt)))
    }
}
