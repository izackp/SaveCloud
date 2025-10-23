//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/23/24.
//

import Vapor
import Argon2Swift
import HRW

struct EditUserRequest: Content {
    let username: String
    let email: String
    let password: String
    
    func validate() -> String? {
        if (username.isEmpty) {
            return "Username is empty."
        }
        if (email.isEmpty) {
            return "Email is empty."
        }
        if (password.isEmpty) {
            return "Password is empty."
        }
        
        return nil
    }
}

struct EditUserForm {
    let binding:EditUserFormBinding
    let rootNode:Form
    
    public init(_ app:Application, user:User, error:String?) throws {
        let nodes = try app.readHtmlFromFile("EditUserForm.html")
        let rootNode = nodes.first as! Form
        binding = try EditUserFormBinding(rootNode: rootNode)
        self.rootNode = rootNode
        
        if let passwordHash = user.passwordHash {
            binding.password_hash.addChild(HTMLText(content: passwordHash))
            binding.password_container.globalAttributes[.style] = ""
        }
        if let error = error {
            binding.span_error.addChild(HTMLText(content: error))
            binding.error_container.globalAttributes[.style] = ""
        }
    }
}

extension Request {
    func fetchSession() throws -> AuthSession? {
        guard let sessionId = session.authenticated(AuthSession.self) else { return nil }
        let connection = try Database.getConnection()
        let session = try connection.first(AuthSession.self, uuid:sessionId)
        return session
    }
}

@Sendable func editUser(req: Request) async throws -> Response {
    let connection = try Database.getConnection()
    let app = req.application
    guard
        let session = try req.fetchSession(),
        let user = try connection.first(User.self, uuid:session.user) else {
        return try WelcomePage(app, users:[], error:"Session doesn't exist").rootNode.response()
    }
    
    let contents = try req.content.decode(EditUserRequest.self)
    let error = contents.validate()
    if let error = error {
        let response = try EditUserPage(app, user: user, userEditError: error, passwordEditError: nil).rootNode
        return response.response()
    }
    
    let verified = try Argon2Swift.verifyHashString(password: contents.password, hash: user.passwordHash ?? "")
    if (!verified) {
        return try EditUserPage(app, user: user, userEditError: nil, passwordEditError: "Password is incorrect.").rootNode.response()
    }
    
    user.email = contents.email
    user.username = contents.username
    user.updatedAt = Date()
    try connection.update(User.self, item:user)
    
    let response = try EditUserPage(app, user: user, userEditError: nil, passwordEditError: nil).rootNode
    return response.response()
}
