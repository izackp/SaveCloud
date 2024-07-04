//
//  PageInfo.swift
//  
//
//  Created by Isaac Paul on 7/3/24.
//

public enum PageSortBy : UInt16, Sendable, LosslessStringConvertible {
    public init?(_ description: String) {
        switch (description) {
            case "date":
                self.init(rawValue: PageSortBy.date.rawValue)
                break
            case "created_at":
                self.init(rawValue: PageSortBy.createdAt.rawValue)
                break
            case "updated_at":
                self.init(rawValue: PageSortBy.updatedAt.rawValue)
                break
            case "id":
                self.init(rawValue: PageSortBy.id.rawValue)
                break
            default:
                return nil
        }
    }
    
    public var description: String {
        get {
            switch (self) {
                case PageSortBy.date:
                    return "date"
                case PageSortBy.createdAt:
                    return "created_at"
                case PageSortBy.updatedAt:
                    return "updated_at"
                case PageSortBy.id:
                    return "id"
            }
        }
    }
    
    case date
    case createdAt
    case updatedAt
    case id
}

public struct PageInfo {
    public init(page: UInt? = nil, perPage: UInt? = nil, sortBy: PageSortBy? = nil, sortByAscending:Bool? = nil) {
        self.page = page ?? 0
        self.perPage = perPage ?? 10
        self.sortBy = sortBy ?? PageSortBy.date
        self.sortByAscending = sortByAscending ?? false
    }
    
    let page:UInt
    let perPage:UInt
    let sortBy:PageSortBy
    let sortByAscending:Bool
}
