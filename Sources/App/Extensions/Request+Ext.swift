//
//  File.swift
//  
//
//  Created by Isaac Paul on 7/3/24.
//

import Vapor

extension Request {
    func expectValidAuth() throws -> (UUID, Bool) {
        guard let claims:JWTClaims = self.auth.get() else {
            throw Abort(.internalServerError)
        }
        
        let pathId:UUID? = self.parameters.get("user_id")
        if let pathId = pathId {
            if (pathId != claims.userId && !claims.admin) {
                throw Abort(.unauthorized)
            }
            return (pathId, claims.admin)
        }
        
        return (claims.userId, claims.admin)
    }
    
    func expectValidUserId() throws -> UUID {
        guard let claims:JWTClaims = self.auth.get() else {
            throw Abort(.internalServerError)
        }
        
        let pathId:UUID? = self.parameters.get("user_id")
        if let pathId = pathId {
            if (pathId != claims.userId && !claims.admin) {
                throw Abort(.unauthorized)
            }
            return pathId
        }
        
        return claims.userId
    }
    
    func validUserIdIfExists() throws -> UUID? {
        let pathId:UUID? = self.parameters.get("user_id")
        guard let pathId = pathId else { return nil }
        
        guard let claims:JWTClaims = self.auth.get() else {
            throw Abort(.internalServerError)
        }
        
        if (pathId != claims.userId && !claims.admin) {
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
