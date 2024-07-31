//
//  SaveSortField.swift
//
//
//  Created by Isaac Paul on 7/10/24.
//

public enum SaveSortField : UInt16, Sendable, LosslessStringConvertible, DefaultConstructible {
    public init?(_ description: String) {
        switch (description) {
            case "date":
                self.init(rawValue: SaveSortField.date.rawValue)
                break
            case "created_at":
                self.init(rawValue: SaveSortField.createdAt.rawValue)
                break
            case "updated_at":
                self.init(rawValue: SaveSortField.updatedAt.rawValue)
                break
            case "id":
                self.init(rawValue: SaveSortField.id.rawValue)
                break
            default:
                return nil
        }
    }
    
    public init() {
        self.init(rawValue: SaveSortField.date.rawValue)!
    }
    
    public var description: String {
        get {
            switch (self) {
                case SaveSortField.date:
                    return "date"
                case SaveSortField.createdAt:
                    return "created_at"
                case SaveSortField.updatedAt:
                    return "updated_at"
                case SaveSortField.id:
                    return "id"
            }
        }
    }
    
    case date
    case createdAt
    case updatedAt
    case id
}
