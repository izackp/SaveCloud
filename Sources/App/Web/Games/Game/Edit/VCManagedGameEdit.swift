import Vapor
import HRW

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
