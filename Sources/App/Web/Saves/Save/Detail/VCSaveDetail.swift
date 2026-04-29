import Vapor
import HRW

final class VCSaveDetailPage: SaveDetailPage {
    init(session: AuthSession, save: Save, error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        if let error {
            p_error.addChild(HTMLText(content: error))
            p_error.globalAttributes[.style] = ""
        }
        save_id.addChild(HTMLText(content: save.id.uuidString))
        user_id.addChild(HTMLText(content: save.userId.description))
        profile_id.addChild(HTMLText(content: save.profileId.description))
        game_meta_id.addChild(HTMLText(content: save.gameMetaId?.uuidString ?? ""))
        if let gameMetaId = save.gameMetaId {
            game_meta_id_link.href = URL(string: "/games/\(gameMetaId.uuidString)")
        } else {
            game_meta_id_link.globalAttributes[.style] = "display:none"
        }
        game_hash_id.addChild(HTMLText(content: save.gameHashId.uuidString))
        compatibility_id.addChild(HTMLText(content: save.compatibilityId.uuidString))
        sequential_id.addChild(HTMLText(content: save.sequentialId.uuidString))
        name.addChild(HTMLText(content: save.name ?? ""))
        url.addChild(HTMLText(content: save.url))
        file_size.addChild(HTMLText(content: "\(save.fileSize)"))
        source_device.addChild(HTMLText(content: save.sourceDevice ?? ""))
        content_hash.addChild(HTMLText(content: save.contentHash ?? ""))
        notes.addChild(HTMLText(content: save.notes ?? ""))
        date.addChild(HTMLText(content: String(describing: save.date)))
        created_at.addChild(HTMLText(content: String(describing: save.createdAt)))
        updated_at.addChild(HTMLText(content: String(describing: save.updatedAt)))
        back_link.href = URL(string: "/saves")
    }
}

@Sendable func saveDetailPage(req: Request) async throws -> Response {
    guard let session = try await adminSaveSession(for: req) else {
        return try adminSaveAccessDeniedResponse()
    }
    let pool = DBShared.pool()
    guard let save = try await fetchManagedSave(req: req, pool: pool) else {
        return try VCSavesPage(session: session, saves: [], state: try SavesPageState(req: req), hasNextPage: false, error: "Save not found.").rootNode.response()
    }
    return try VCSaveDetailPage(session: session, save: save, error: nil).rootNode.response()
}
