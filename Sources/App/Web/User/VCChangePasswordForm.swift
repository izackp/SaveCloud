//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/23/24.
//

import Vapor
import Argon2Swift
import GRDB
import HRW

struct ChangePasswordRequest: Content {
    let password_current: String
    let password: String
    let password_confirmation: String
    
    func validate() -> String? {
        if (password_current.isEmpty) {
            return "Current password is empty."
        }
        if (password.isEmpty) {
            return "New password is empty."
        }
        
        return nil
    }
}

class VCChangePasswordForm : ChangePasswordForm {
    
    public init(error:String?) throws {
        try super.init()
        if let error = error {
            span_error.addChild(HTMLText(content: error))
            error_container.globalAttributes[.style] = ""
        }
    }
}

@Sendable func changePassword(req: Request) async throws -> Response {
    let pool = DBShared.pool()
    //let app = req.application
    guard let session = try await req.fetchSession(),
        let user = try await pool.read({ db in
            try User.filter(id: session.user).fetchOne(db)
        }) else {
            return try expiredSessionResponse()
    }
    
    let contents = try req.content.decode(ChangePasswordRequest.self)
    let error = contents.validate()
    if let error = error {
        let response = try VCEditUserPage(user: user, userEditError: error, passwordEditError: error).rootNode
        return response.response()
    }
    if (contents.password != contents.password_confirmation) {
        let response = try VCEditUserPage(user: user, userEditError: nil, passwordEditError: "Passwords do not match.").rootNode
        return response.response()
    }
    
    let verified = try Argon2Swift.verifyHashString(password: contents.password_current, hash: user.passwordHash ?? "")
    if (!verified) {
        return try VCEditUserPage(user: user, userEditError: nil, passwordEditError: "Password is incorrect.").rootNode.response()
    }
    
    let salt = Salt.newSalt()
    let passwordHash = try Argon2Swift.hashPasswordString(password: contents.password, salt: salt).encodedString()
    
    try await pool.write { db in
        _ = try User
            .filter(id: user.id)
            .updateAll(
                db,
                User.password_hash.set(to: passwordHash),
                User.updated_at.set(to: Date())
            )
    }
    
    let response = try VCEditUserPage(user: user, userEditError: nil, passwordEditError: nil).rootNode
    return response.response()
}
