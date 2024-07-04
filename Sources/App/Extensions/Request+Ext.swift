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
    
    func getPageInfo() throws -> PageInfo {
        let page:UInt? = self.parameters.get("page")
        let perPage:UInt? = self.parameters.get("per_page")
        let sortBy:PageSortBy? = self.parameters.get("sort_by")
        let asc:Bool? = self.parameters.get("asc")
        return PageInfo(page: page, perPage: perPage, sortBy: sortBy, sortByAscending: asc)
    }
}
