import Vapor
import HRW

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

@Sendable func gameDetailPage(req: Request) async throws -> Response {
    let viewer = try? await req.fetchSession()
    let pool = DBShared.pool()
    guard let game = try await fetchManagedGame(req: req, pool: pool) else {
        let state = try GamesPageState(req: req)
        return try VCGamesPage(viewer: viewer, games: [], baseGameNamesById: [:], state: state, hasNextPage: false, error: "Game not found.").rootNode.response()
    }
    return try VCGameDetailPage(viewer: viewer, game: game, error: nil).rootNode.response()
}
