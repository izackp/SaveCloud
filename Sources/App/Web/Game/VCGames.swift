import Vapor
import HRW
import GRDB

private func shortListDateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "M/d HH:mm"
    return formatter.string(from: date)
}

private func fullHoverDateText(_ date: Date) -> String {
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

final class VCGamesTableRow: GamesTableRow {
    init(game: GameMeta, baseGameNamesById: [UUID: String], isAdmin: Bool) throws {
        try super.init()
        name.addChild(HTMLText(content: game.name))
        name_link.href = URL(string: "/games/\(game.id.uuidString)")
        version.addChild(HTMLText(content: game.version ?? "N/A"))
        if let familyId = game.familyId {
            version_link.href = URL(string: "/games?family_id_search=\(familyId.uuidString)")
        }
        if let baseGameId = game.baseGameId {
            base_game_name.addChild(HTMLText(content: baseGameNamesById[baseGameId] ?? baseGameId.uuidString))
            base_game_link.href = URL(string: "/games/\(baseGameId.uuidString)")
        } else {
            base_game_name.addChild(HTMLText(content: ""))
            base_game_link.globalAttributes[.style] = "display:none"
        }
        breaks_prev.addChild(HTMLText(content: game.breaksSaveFormatFromPreviousVersion ? "Yes" : "No"))
        breaks_base.addChild(HTMLText(content: game.breaksSaveFormatFromBaseGame ? "Yes" : "No"))
        created_at.addChild(HTMLText(content: shortListDateText(game.createdAt)))
        created_at.globalAttributes[.title] = fullHoverDateText(game.createdAt)
        updated_at.addChild(HTMLText(content: shortListDateText(game.updatedAt)))
        updated_at.globalAttributes[.title] = fullHoverDateText(game.updatedAt)
        if isAdmin {
            edit_link.href = URL(string: "/games/\(game.id.uuidString)/edit")
            delete_link.href = URL(string: "/games/\(game.id.uuidString)/delete")
        } else {
            edit_link.globalAttributes[.style] = "display:none"
            delete_link.globalAttributes[.style] = "display:none"
            actions_gap.globalAttributes[.style] = "display:none"
        }
    }
}

final class VCGamesPage: GamesPage {
    init(viewer: AuthSession?, games: [GameMeta], baseGameNamesById: [UUID: String], state: GamesPageState, hasNextPage: Bool, error: String?) throws {
        try super.init()
        if let viewer {
            nav_bar.addChild(try VCNavBar(isAdmin: viewer.isAdmin).rootNode)
        }
        if let error {
            p_error.addChild(HTMLText(content: error))
            p_error.globalAttributes[.style] = ""
        }
        sort_name_link.href = URL(string: state.sortURL(.name))
        sort_created_at_link.href = URL(string: state.sortURL(.createdAt))
        sort_updated_at_link.href = URL(string: state.sortURL(.updatedAt))
        for game in games {
            table.children.append(try VCGamesTableRow(game: game, baseGameNamesById: baseGameNamesById, isAdmin: viewer?.isAdmin == true).rootNode)
        }
        page_text.addChild(HTMLText(content: "Page \(state.pageInfo.page + 1)"))
        if state.pageInfo.page > 0 {
            prev_link.href = URL(string: "/games?\(state.queryString(page: state.pageInfo.page - 1))")
            prev_link.globalAttributes[.style] = ""
        }
        if hasNextPage {
            next_link.href = URL(string: "/games?\(state.queryString(page: state.pageInfo.page + 1))")
            next_link.globalAttributes[.style] = ""
        }
    }
}

final class VCGameDetailPage: GameDetailPage {
    init(viewer: AuthSession?, game: GameMeta, error: String?) throws {
        try super.init()
        if let viewer {
            nav_bar.addChild(try VCNavBar(isAdmin: viewer.isAdmin).rootNode)
        }
        if let error {
            p_error.addChild(HTMLText(content: error))
            p_error.globalAttributes[.style] = ""
        }
        game_id.addChild(HTMLText(content: game.id.uuidString))
        name.addChild(HTMLText(content: game.name))
        version.addChild(HTMLText(content: game.version ?? ""))
        family_id.addChild(HTMLText(content: game.familyId?.uuidString ?? ""))
        if let familyId = game.familyId {
            family_id_link.href = URL(string: "/games?family_id_search=\(familyId.uuidString)")
        } else {
            family_id_link.globalAttributes[.style] = "display:none"
        }
        base_game_id.addChild(HTMLText(content: game.baseGameId?.uuidString ?? ""))
        hashed_file_name.addChild(HTMLText(content: game.hashedFileName ?? ""))
        xxhash64.addChild(HTMLText(content: game.xxhash64 ?? ""))
        breaks_prev.addChild(HTMLText(content: game.breaksSaveFormatFromPreviousVersion ? "Yes" : "No"))
        breaks_base.addChild(HTMLText(content: game.breaksSaveFormatFromBaseGame ? "Yes" : "No"))
        created_at.addChild(HTMLText(content: String(describing: game.createdAt)))
        updated_at.addChild(HTMLText(content: String(describing: game.updatedAt)))
        back_link.href = URL(string: "/games")
    }
}

final class VCManagedGameForm: ManagedGameForm {
    init(game: GameMeta, error: String?) throws {
        try super.init()
        rootNode.action = URL(string: "/games/\(game.id.uuidString)/edit")
        game_id.addChild(HTMLText(content: game.id.uuidString))
        name.value = game.name
        version.value = game.version ?? ""
        family_id.value = game.familyId?.uuidString ?? ""
        base_game_id.value = game.baseGameId?.uuidString ?? ""
        hashed_file_name.value = game.hashedFileName ?? ""
        xxhash64.value = game.xxhash64 ?? ""
        breaks_save_format_from_previous_version.checked = game.breaksSaveFormatFromPreviousVersion
        breaks_save_format_from_base_game.checked = game.breaksSaveFormatFromBaseGame
        created_at.addChild(HTMLText(content: String(describing: game.createdAt)))
        updated_at.addChild(HTMLText(content: String(describing: game.updatedAt)))
        if let error {
            span_error.addChild(HTMLText(content: error))
            error_container.globalAttributes[.style] = ""
        }
    }
}

final class VCManagedGamePage: ManagedGamePage {
    init(session: AuthSession, game: GameMeta, error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        form_container.addChild(try VCManagedGameForm(game: game, error: error).rootNode)
    }
}

final class VCDeleteManagedGamePage: DeleteManagedGamePage {
    init(session: AuthSession, game: GameMeta) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        game_id.addChild(HTMLText(content: game.id.uuidString))
        name.addChild(HTMLText(content: game.name))
        version.addChild(HTMLText(content: game.version ?? ""))
        base_game_id.addChild(HTMLText(content: game.baseGameId?.uuidString ?? ""))
        delete_form.action = URL(string: "/games/\(game.id.uuidString)/delete")
        cancel_link.href = URL(string: "/games")
    }
}

private func adminGameSession(for req: Request) async throws -> AuthSession? {
    guard let session = try await req.fetchSession(), session.isAdmin else {
        return nil
    }
    return session
}

private func adminGameAccessDeniedResponse() throws -> Response {
    try VCWelcomePage(users: [], error: "Admin access required.").rootNode.response()
}

private func fetchManagedGame(req: Request, pool: DatabasePool) async throws -> GameMeta? {
    guard let gameId: UUID = req.parameters.get("game_id") else {
        return nil
    }
    return try await pool.read { db in
        try GameMeta.filter(id: gameId).fetchOne(db)
    }
}

@Sendable func gamesPage(req: Request) async throws -> Response {
    let viewer = try? await req.fetchSession()
    let state = try GamesPageState(req: req)
    let pageInfo = state.pageInfo
    let searches = GameMetaSearchField.searchFieldsInRequest(req)
    let effectiveSearches: [SearchQuery<GameMetaSearchField>] = if let familyId = state.familyId {
        searches + [SearchQuery(searchBy: .familyId, value: familyId.uuidString)]
    } else {
        searches
    }
    let isFamilySearch = effectiveSearches.contains { $0.searchBy == .familyId }

    let pageGames: [GameMeta]
    let hasNextPage: Bool
    if isFamilySearch {
        pageGames = try GameMeta.fetchPaged(pageInfo, onlyBaseGames: false, searchList: effectiveSearches)
        let nextPageInfo = PageInfo<GameMetaSortField>(
            page: pageInfo.page + 1,
            perPage: pageInfo.perPage,
            sortBy: pageInfo.sortBy,
            sortByAscending: pageInfo.sortByAscending
        )
        hasNextPage = !(try GameMeta.fetchPaged(nextPageInfo, onlyBaseGames: false, searchList: effectiveSearches).isEmpty)
    } else {
        pageGames = try GameMeta.fetchLatestPerFamilyPaged(pageInfo, searchList: effectiveSearches)
        let nextPageInfo = PageInfo<GameMetaSortField>(
            page: pageInfo.page + 1,
            perPage: pageInfo.perPage,
            sortBy: pageInfo.sortBy,
            sortByAscending: pageInfo.sortByAscending
        )
        hasNextPage = !(try GameMeta.fetchLatestPerFamilyPaged(nextPageInfo, searchList: effectiveSearches).isEmpty)
    }
    let baseGameIds = Array(Set(pageGames.compactMap(\.baseGameId)))
    let baseGameNamesById: [UUID: String]
    if baseGameIds.isEmpty {
        baseGameNamesById = [:]
    } else {
        let pool = DBShared.pool()
        let baseGames = try await pool.read { db in
            try GameMeta
                .filter(baseGameIds.contains(GameMeta.id))
                .fetchAll(db)
        }
        baseGameNamesById = Dictionary(uniqueKeysWithValues: baseGames.map { ($0.id, $0.name) })
    }
    return try VCGamesPage(viewer: viewer, games: pageGames, baseGameNamesById: baseGameNamesById, state: state, hasNextPage: hasNextPage, error: nil).rootNode.response()
}

@Sendable func gameDetailPage(req: Request) async throws -> Response {
    let viewer = try? await req.fetchSession()
    let pool = DBShared.pool()
    guard let game = try await fetchManagedGame(req: req, pool: pool) else {
        let state = try GamesPageState(req: req)
        return try VCGamesPage(viewer: viewer, games: [], baseGameNamesById: [:], state: state, hasNextPage: false, error: "Game not found.").rootNode.response()
    }
    return try VCGameDetailPage(viewer: viewer, game: game, error: nil).rootNode.response()
}

@Sendable func editGamePage(req: Request) async throws -> Response {
    guard let session = try await adminGameSession(for: req) else {
        return try adminGameAccessDeniedResponse()
    }
    let pool = DBShared.pool()
    guard let game = try await fetchManagedGame(req: req, pool: pool) else {
        return try VCGamesPage(viewer: session, games: [], baseGameNamesById: [:], state: try GamesPageState(req: req), hasNextPage: false, error: "Game not found.").rootNode.response()
    }
    return try VCManagedGamePage(session: session, game: game, error: nil).rootNode.response()
}

@Sendable func updateGame(req: Request) async throws -> Response {
    guard let session = try await adminGameSession(for: req) else {
        return try adminGameAccessDeniedResponse()
    }
    let pool = DBShared.pool()
    guard let game = try await fetchManagedGame(req: req, pool: pool) else {
        return try VCGamesPage(viewer: session, games: [], baseGameNamesById: [:], state: try GamesPageState(req: req), hasNextPage: false, error: "Game not found.").rootNode.response()
    }

    let contents = try req.content.decode(ManagedGameRequest.self)
    if let error = contents.validate() {
        return try VCManagedGamePage(session: session, game: game, error: error).rootNode.response()
    }

    let updatedGame = try await pool.write { db in
        var updated = game
        updated.name = contents.name
        updated.version = contents.version?.isEmpty == false ? contents.version : nil
        updated.familyId = contents.family_id?.isEmpty == false ? UUID(uuidString: contents.family_id!) : nil
        updated.baseGameId = contents.base_game_id?.isEmpty == false ? UUID(uuidString: contents.base_game_id!) : nil
        updated.hashedFileName = contents.hashed_file_name?.isEmpty == false ? contents.hashed_file_name : nil
        updated.xxhash64 = contents.xxhash64?.isEmpty == false ? contents.xxhash64 : nil
        updated.breaksSaveFormatFromPreviousVersion = contents.breaksPrevious
        updated.breaksSaveFormatFromBaseGame = contents.breaksBase
        updated.updatedAt = Date()
        try updated.update(db)
        return updated
    }

    return try VCManagedGamePage(session: session, game: updatedGame, error: nil).rootNode.response()
}

@Sendable func deleteGamePage(req: Request) async throws -> Response {
    guard let session = try await adminGameSession(for: req) else {
        return try adminGameAccessDeniedResponse()
    }
    let pool = DBShared.pool()
    guard let game = try await fetchManagedGame(req: req, pool: pool) else {
        return try VCGamesPage(viewer: session, games: [], baseGameNamesById: [:], state: try GamesPageState(req: req), hasNextPage: false, error: "Game not found.").rootNode.response()
    }
    return try VCDeleteManagedGamePage(session: session, game: game).rootNode.response()
}

@Sendable func deleteGame(req: Request) async throws -> Response {
    guard let session = try await adminGameSession(for: req) else {
        return try adminGameAccessDeniedResponse()
    }
    guard let gameId: UUID = req.parameters.get("game_id") else {
        throw Abort(.badRequest)
    }
    let contents = try req.content.decode(DeleteGameRequest.self)
    let pool = DBShared.pool()
    do {
        try await pool.write { db in
            guard let target = try GameMeta.filter(id: gameId).fetchOne(db) else {
                throw Abort(.notFound)
            }
            let parentId = target.baseGameId
            if let parentId, contents.replaceWithParent {
                try GameHash.replaceGameMeta(db, targetUUID: gameId, replaceWith: parentId)
                try GameMeta.replaceBaseGameId(db, targetUUID: gameId, replaceWith: parentId)
                try GameMeta.filter(id: gameId).deleteAll(db)
            } else if contents.allowBreak {
                try GameHash.replaceGameMeta(db, targetUUID: gameId, replaceWith: nil)
                try GameMeta.replaceBaseGameId(db, targetUUID: gameId, replaceWith: nil)
                try GameMeta.filter(id: gameId).deleteAll(db)
            } else {
                let hashCount = try GameHash.filter(GameHash.gameMetaId == gameId).fetchCount(db)
                if hashCount > 0 {
                    throw Abort(.forbidden, reason: "There are game hashes that depend on this game meta.")
                }

                let metaCount = try GameMeta.filter(GameMeta.baseGameId == gameId).fetchCount(db)
                if metaCount > 0 {
                    throw Abort(.forbidden, reason: "This game meta has other dependents as children.")
                }
                try GameMeta.filter(id: gameId).deleteAll(db)
            }
        }
    } catch let error as AbortError {
        let game = try await fetchManagedGame(req: req, pool: pool) ?? GameMeta(
            id: gameId,
            name: "",
            breaksSaveFormatFromPreviousVersion: false,
            breaksSaveFormatFromBaseGame: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        return try VCManagedGamePage(session: session, game: game, error: error.reason).rootNode.response()
    }
    return req.redirect(to: "/games", redirectType: .normal)
}
