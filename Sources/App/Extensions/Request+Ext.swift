//
//  File.swift
//  
//
//  Created by Isaac Paul on 7/3/24.
//

import Vapor

extension Request {
    private func userPathId() -> SmallUid? {
        self.parameters.get("user_id")
    }

    func idFromParameterOrQuery(_ name: String) -> SmallUid? {
        if let value: SmallUid = self.parameters.get(name) {
            return value
        }
        return try? self.query.get(SmallUid.self, at: name)
    }

    func authSession() throws -> AuthSession {
        guard let session: AuthSession = self.auth.get() else {
            throw Abort(.unauthorized)
        }
        return session
    }
    
    func expectValidAuth() throws -> (SmallUid, Bool) {
        let session = try authSession()
        
        let pathId = userPathId()
        if let pathId = pathId {
            if (pathId != session.user && !session.isAdmin) {
                throw Abort(.unauthorized)
            }
            return (pathId, session.isAdmin)
        }
        
        return (session.user, session.isAdmin)
    }
    
    func expectValidUserId() throws -> SmallUid {
        let session = try authSession()
        
        let pathId = userPathId()
        if let pathId = pathId {
            if (pathId != session.user && !session.isAdmin) {
                throw Abort(.unauthorized)
            }
            return pathId
        }
        
        return session.user
    }
    
    func validUserIdIfExists() throws -> SmallUid? {
        let pathId = userPathId()
        guard let pathId = pathId else { return nil }
        
        let session = try authSession()
        
        if (pathId != session.user && !session.isAdmin) {
            throw Abort(.unauthorized)
        }
        return pathId
    }
    
    func getPageInfo<T: LosslessStringConvertible & DefaultConstructible>() throws -> PageInfo<T> {
        let page = try? self.query.get(UInt.self, at: "page")
        let perPage = try? self.query.get(UInt.self, at: "per_page")
        let sortBy:T
        if let sortByParam = try? self.query.get(String.self, at: "sort_by") { //TODO: Sanitize
            if let matching = T(sortByParam) {
                sortBy = matching
            } else {
                throw AppError("Can't sort by field: \(sortByParam)")
            }
        } else {
            sortBy = T()
        }
        let asc = try? self.query.get(Bool.self, at: "asc")
        return PageInfo(page: page, perPage: perPage, sortBy: sortBy, sortByAscending: asc)
    }
    
    func getSearchField<T: LosslessStringConvertible & DefaultConstructible>(field:T, name:String) throws -> SearchQuery<T>? {
        guard let search = try? self.query.get(String.self, at: "\(name)_search") else {
            return nil
        }
        
        return SearchQuery(searchBy: field, value: search)
    }
}
