//
//  File.swift
//  
//
//  Created by Isaac Paul on 7/3/24.
//

import Vapor

extension Request {
    private func userPathId() -> UUID? {
        self.parameters.get("user_id")
    }

    func authSession() throws -> AuthSession {
        guard let session: AuthSession = self.auth.get() else {
            throw Abort(.unauthorized)
        }
        return session
    }
    
    func expectValidAuth() throws -> (UUID, Bool) {
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
    
    func expectValidUserId() throws -> UUID {
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
    
    func validUserIdIfExists() throws -> UUID? {
        let pathId = userPathId()
        guard let pathId = pathId else { return nil }
        
        let session = try authSession()
        
        if (pathId != session.user && !session.isAdmin) {
            throw Abort(.unauthorized)
        }
        return pathId
    }
    
    func getPageInfo<T: LosslessStringConvertible & DefaultConstructible>() throws -> PageInfo<T> {
        let page:UInt? = self.parameters.get("page")
        let perPage:UInt? = self.parameters.get("per_page")
        let sortBy:T
        if let sortByParam = self.parameters.get("sort_by") { //TODO: Sanitize
            if let matching = T(sortByParam) {
                sortBy = matching
            } else {
                throw AppError("Can't sort by field: \(sortByParam)")
            }
        } else {
            sortBy = T()
        }
        let asc:Bool? = self.parameters.get("asc")
        return PageInfo(page: page, perPage: perPage, sortBy: sortBy, sortByAscending: asc)
    }
    
    func getSearchField<T: LosslessStringConvertible & DefaultConstructible>(field:T, name:String) throws -> SearchQuery<T>? {
        guard let search:String = self.parameters.get("\(name)_search") else {
            return nil
        }
        
        return SearchQuery(searchBy: field, value: search)
    }
}
