//
//  GameMetaSortField.swift
//
//
//  Created by Isaac Paul on 7/10/24.
//

import Vapor

public enum GameMetaSortField : UInt16, Sendable, LosslessStringConvertible, DefaultConstructible {
    public init?(_ description: String) {
        switch (description) {
            case "name":
                self.init(rawValue: GameMetaSortField.name.rawValue)
                break
            case "created_at":
                self.init(rawValue: GameMetaSortField.createdAt.rawValue)
                break
            case "updated_at":
                self.init(rawValue: GameMetaSortField.updatedAt.rawValue)
                break
            case "id":
                self.init(rawValue: GameMetaSortField.id.rawValue)
                break
            default:
                return nil
        }
    }
    
    public init() {
        self.init(rawValue: GameMetaSortField.name.rawValue)!
    }
    
    public var description: String {
        get {
            switch (self) {
                case GameMetaSortField.name:
                    return "name"
                case GameMetaSortField.createdAt:
                    return "created_at"
                case GameMetaSortField.updatedAt:
                    return "updated_at"
                case GameMetaSortField.id:
                    return "id"
            }
        }
    }
    
    case name
    case createdAt
    case updatedAt
    case id
}

public enum GameMetaSearchField : UInt16, Sendable, LosslessStringConvertible, DefaultConstructible {
    public init?(_ description: String) {
        switch (description) {
            case "name":
                self.init(rawValue: GameMetaSearchField.name.rawValue)
                break
            case "familyId":
                self.init(rawValue: GameMetaSearchField.familyId.rawValue)
                break
            case "hashedFileName":
                self.init(rawValue: GameMetaSearchField.hashedFileName.rawValue)
                break
            case "xxhash64":
                self.init(rawValue: GameMetaSearchField.xxhash64.rawValue)
                break
            case "version":
                self.init(rawValue: GameMetaSearchField.version.rawValue)
                break
            case "id":
                self.init(rawValue: GameMetaSearchField.id.rawValue)
                break
            default:
                return nil
        }
    }
    
    public init() {
        self.init(rawValue: GameMetaSearchField.name.rawValue)!
    }
    
    public var description: String {
        get {
            switch (self) {
                case GameMetaSearchField.name:
                    return "name"
                case GameMetaSearchField.familyId:
                    return "familyId"
                case GameMetaSearchField.hashedFileName:
                    return "hashedFileName"
                case GameMetaSearchField.xxhash64:
                    return "xxhash64"
                case GameMetaSearchField.version:
                    return "version"
                case GameMetaSearchField.id:
                    return "id"
            }
        }
    }
    
    public var urlKey: String {
        get {
            switch (self) {
                case GameMetaSearchField.name:
                    return "name"
                case GameMetaSearchField.familyId:
                    return "family_id"
                case GameMetaSearchField.hashedFileName:
                    return "hashed_file_name"
                case GameMetaSearchField.xxhash64:
                    return "xxhash64"
                case GameMetaSearchField.version:
                    return "version"
                case GameMetaSearchField.id:
                    return "id"
            }
        }
    }
    
    case name
    case familyId
    case hashedFileName
    case xxhash64
    case version
    case id
    
    static let allFields:[GameMetaSearchField] = [.name, .familyId, .hashedFileName, .xxhash64, .version, .id]
    
    public static func searchFieldsInRequest(_ req:Request) -> [SearchQuery<GameMetaSearchField>] {
        var result = allFields.compactMap({
            if let search:String = req.parameters.get("\($0.urlKey)_search") {
                return SearchQuery(searchBy: $0, value: search)
            }
            return nil
        })
        return result
    }
}

