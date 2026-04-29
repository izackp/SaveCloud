import Vapor
import HRW
import GRDB

struct SavesPageState {
    let pageInfo: PageInfo<SaveSortField>

    init(req: Request) throws {
        pageInfo = try req.getPageInfo()
    }

    func queryItems(page: UInt? = nil, sortBy: SaveSortField? = nil, asc: Bool? = nil) -> [String] {
        [
            "page=\(page ?? pageInfo.page)",
            "per_page=\(pageInfo.perPage)",
            "sort_by=\((sortBy ?? pageInfo.sortBy).description)",
            "asc=\((asc ?? pageInfo.sortByAscending) ? "1" : "0")"
        ]
    }

    func queryString(page: UInt? = nil, sortBy: SaveSortField? = nil, asc: Bool? = nil) -> String {
        queryItems(page: page, sortBy: sortBy, asc: asc).joined(separator: "&")
    }

    func sortURL(_ sortBy: SaveSortField) -> String {
        let nextAscending: Bool
        if pageInfo.sortBy == sortBy {
            nextAscending = !pageInfo.sortByAscending
        } else {
            nextAscending = true
        }
        return "/saves?\(queryString(page: 0, sortBy: sortBy, asc: nextAscending))"
    }
}

func adminSaveSession(for req: Request) async throws -> AuthSession? {
    guard let session = try await req.fetchSession(), session.isAdmin else {
        return nil
    }
    return session
}

func adminSaveAccessDeniedResponse() throws -> Response {
    try VCWelcomePage(users: [], error: "Admin access required.").rootNode.response()
}

func fetchManagedSave(req: Request, pool: DatabasePool) async throws -> Save? {
    guard let saveId: UUID = req.parameters.get("save_id") else {
        return nil
    }
    return try await pool.read { db in
        try Save.filter(id: saveId).fetchOne(db)
    }
}
