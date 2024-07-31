//
//  PageInfo.swift
//  
//
//  Created by Isaac Paul on 7/3/24.
//

public struct PageInfo<T: LosslessStringConvertible & DefaultConstructible> {
    public init(page: UInt? = nil, perPage: UInt? = nil, sortBy: T, sortByAscending:Bool? = nil) {
        self.page = page ?? 0
        self.perPage = perPage ?? 10
        self.sortBy = sortBy
        self.sortByAscending = sortByAscending ?? false
    }
    
    let page:UInt
    let perPage:UInt
    let sortBy:T
    let sortByAscending:Bool
}
