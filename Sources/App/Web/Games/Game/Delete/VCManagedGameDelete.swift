import Vapor
import HRW

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
                let hashCount = try GameHash
                    .filter(sql: "game_meta_id = ?", arguments: [gameId])
                    .fetchCount(db)
                if hashCount > 0 {
                    throw Abort(.forbidden, reason: "There are game hashes that depend on this game meta.")
                }

                let metaCount = try GameMeta
                    .filter(sql: "base_game_id = ?", arguments: [gameId])
                    .fetchCount(db)
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
