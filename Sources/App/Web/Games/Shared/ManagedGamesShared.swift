import Vapor
import HRW
import GRDB

func shortListDateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "M/d HH:mm"
    return formatter.string(from: date)
}

func fullHoverDateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter.string(from: date)
}

struct ManagedGameRequest: Content {
    let name: String
    let version: String?
    let family_id: String?
    let base_game_id: String?
    let hashed_file_name: String?
    let xxhash64: String?
    let breaks_save_format_from_previous_version: String?
    let breaks_save_format_from_base_game: String?

    var breaksPrevious: Bool {
        breaks_save_format_from_previous_version != nil
    }

    var breaksBase: Bool {
        breaks_save_format_from_base_game != nil
    }

    func validate() -> String? {
        if name.isEmpty {
            return "Name is empty."
        }
        if let family_id, !family_id.isEmpty, UUID(uuidString: family_id) == nil {
            return "Family ID is invalid."
        }
        if let base_game_id, !base_game_id.isEmpty, UUID(uuidString: base_game_id) == nil {
            return "Base Game ID is invalid."
        }
        return nil
    }
}

struct DeleteGameRequest: Content {
    let replace_with_parent: String?
    let allow_break: String?

    var replaceWithParent: Bool {
        replace_with_parent != nil
    }

    var allowBreak: Bool {
        allow_break != nil
    }
}

struct GamesPageState {
    let pageInfo: PageInfo<GameMetaSortField>
    let familyId: UUID?
    let hash: String?

    init(req: Request) throws {
        pageInfo = try req.getPageInfo()
        familyId = try? req.query.get(UUID.self, at: "family_id_search")
        hash = try? req.query.get(String.self, at: "hash")
    }

    func queryItems(page: UInt? = nil, sortBy: GameMetaSortField? = nil, asc: Bool? = nil) -> [String] {
        var items = [String]()
        items.append("page=\(page ?? pageInfo.page)")
        items.append("per_page=\(pageInfo.perPage)")
        items.append("sort_by=\((sortBy ?? pageInfo.sortBy).description)")
        items.append("asc=\((asc ?? pageInfo.sortByAscending) ? "1" : "0")")
        if let familyId {
            items.append("family_id_search=\(familyId.uuidString)")
        }
        if let hash, !hash.isEmpty {
            items.append("hash=\(hash)")
        }
        return items
    }

    func queryString(page: UInt? = nil, sortBy: GameMetaSortField? = nil, asc: Bool? = nil) -> String {
        queryItems(page: page, sortBy: sortBy, asc: asc).joined(separator: "&")
    }

    func sortURL(_ sortBy: GameMetaSortField) -> String {
        let nextAscending: Bool
        if pageInfo.sortBy == sortBy {
            nextAscending = !pageInfo.sortByAscending
        } else {
            nextAscending = true
        }
        return "/games?\(queryString(page: 0, sortBy: sortBy, asc: nextAscending))"
    }
}

func adminGameSession(for req: Request) async throws -> AuthSession? {
    guard let session = try await req.fetchSession(), session.isAdmin else {
        return nil
    }
    return session
}

func adminGameAccessDeniedResponse() throws -> Response {
    try VCWelcomePage(users: [], error: "Admin access required.").rootNode.response()
}

func fetchManagedGame(req: Request, pool: DatabasePool) async throws -> GameMeta? {
    guard let gameId: UUID = req.parameters.get("game_id") else {
        return nil
    }
    return try await pool.read { db in
        try GameMeta.filter(id: gameId).fetchOne(db)
    }
}
