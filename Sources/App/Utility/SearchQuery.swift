//
//  File.swift
//  
//
//  Created by Isaac Paul on 7/10/24.
//

public struct SearchQuery<T> {
    public init(searchBy: T, value: String) {
        self.searchBy = searchBy
        self.value = value
    }

    let searchBy:T
    let value:String
}
