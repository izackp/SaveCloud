import Vapor
import HRW

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
