//
//  HomePage.swift
//  
//
//  Created by Isaac Paul on 5/23/24.
//

import Vapor
import HRW

class VCHomePage : HomePage {
    
    public init(isAdmin:Bool, message: String? = nil) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: isAdmin).rootNode)
        if let message {
            p_message.addChild(HTMLText(content: message))
            p_message.globalAttributes[.style] = ""
        }
        if isAdmin {
            admin_tools.globalAttributes[.style] = ""
        }
    }
}

@Sendable func reseedDatabase(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession(), session.isAdmin else {
        return try VCWelcomePage(users: [], error: "Admin access required.").rootNode.response()
    }

    let pool = DBShared.pool()
    guard let user = try await pool.read({ db in
        try User.filter(id: session.user).fetchOne(db)
    }) else {
        return try VCWelcomePage(users: [], error: "User not found.").rootNode.response()
    }

    try DBShared.reseedPreserving(currentUser: user, currentSession: session)
    return try VCHomePage(
        isAdmin: true,
        message: "Database reseeded. Your current user and current session were preserved."
    ).rootNode.response()
}
