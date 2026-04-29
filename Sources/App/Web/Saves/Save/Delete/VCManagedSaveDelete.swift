import Vapor
import HRW

final class VCDeleteManagedSavePage: DeleteManagedSavePage {
    init(session: AuthSession, save: Save) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        save_id.addChild(HTMLText(content: save.id.uuidString))
        user_id.addChild(HTMLText(content: save.userId.description))
        profile_id.addChild(HTMLText(content: save.profileId.description))
        game_meta_id.addChild(HTMLText(content: save.gameMetaId?.uuidString ?? ""))
        name.addChild(HTMLText(content: save.name ?? ""))
        delete_form.action = URL(string: "/saves/\(save.id.uuidString)/delete")
        cancel_link.href = URL(string: "/saves")
    }
}

@Sendable func deleteSavePage(req: Request) async throws -> Response {
    guard let session = try await adminSaveSession(for: req) else {
        return try adminSaveAccessDeniedResponse()
    }
    let pool = DBShared.pool()
    guard let save = try await fetchManagedSave(req: req, pool: pool) else {
        return try VCSavesPage(session: session, saves: [], state: try SavesPageState(req: req), hasNextPage: false, error: "Save not found.").rootNode.response()
    }
    return try VCDeleteManagedSavePage(session: session, save: save).rootNode.response()
}

@Sendable func deleteSave(req: Request) async throws -> Response {
    guard let session = try await adminSaveSession(for: req) else {
        return try adminSaveAccessDeniedResponse()
    }
    guard let saveId: UUID = req.parameters.get("save_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    do {
        try await pool.write { db in
            _ = try Save.filter(id: saveId).deleteAll(db)
        }
    } catch let error as AbortError {
        return try VCSavesPage(session: session, saves: [], state: try SavesPageState(req: req), hasNextPage: false, error: error.reason).rootNode.response()
    }
    return req.redirect(to: "/saves", redirectType: .normal)
}
