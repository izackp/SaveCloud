import Vapor
import HRW

final class VCDeleteProfileSavePage: DeleteProfileSavePage {
    init(session: AuthSession, profile: UserProfile, game: GameMeta?, save: Save, deletePath: String, cancelPath: String) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        title.addChild(HTMLText(content: "Delete Save"))
        message.addChild(HTMLText(content: "This will permanently delete this save."))
        game_name.addChild(HTMLText(content: game?.name ?? "Unknown game"))
        profile_name.addChild(HTMLText(content: profile.name))
        save_name.addChild(HTMLText(content: save.name ?? "Untitled save"))
        let saveDate = save.date ?? save.updatedAt
        save_date.addChild(HTMLText(content: fullProfileSaveDateText(saveDate)))
        delete_form.action = URL(string: deletePath)
        delete_button.addChild(HTMLText(content: "Delete Save"))
        cancel_link.href = URL(string: cancelPath)
    }
}

@Sendable func userProfileSaveDownload(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try expiredSessionResponse()
    }
    guard let saveId: UUID = req.parameters.get("save_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchAccessibleProfile(req: req, session: session, pool: pool),
          let save = try await fetchProfileSave(userId: profile.userId, profile: profile, saveId: saveId, pool: pool) else {
        return try await profileNotFoundResponse(session: session, req: req, pool: pool, error: "Profile or save not found.")
    }
    return req.redirect(to: save.url, redirectType: .normal)
}

@Sendable func deleteUserProfileSavePage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try expiredSessionResponse()
    }
    guard let saveId: UUID = req.parameters.get("save_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchAccessibleProfile(req: req, session: session, pool: pool),
          let save = try await fetchProfileSave(userId: profile.userId, profile: profile, saveId: saveId, pool: pool) else {
        return try await profileNotFoundResponse(session: session, req: req, pool: pool, error: "Profile or save not found.")
    }
    let nav = profileNavigationContext(session: session, profile: profile)
    let game = try await pool.read { db -> GameMeta? in
        guard let gameId = save.gameMetaId else {
            return nil
        }
        return try GameMeta.filter(id: gameId).fetchOne(db)
    }
    let cancelPath = "\(nav.sequenceBasePath)/\(save.sequentialId.uuidString)"
    return try VCDeleteProfileSavePage(session: session, profile: profile, game: game, save: save, deletePath: "\(nav.savesBasePath)/\(save.id.uuidString)/delete", cancelPath: cancelPath).rootNode.response()
}

@Sendable func deleteUserProfileSave(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try expiredSessionResponse()
    }
    guard let saveId: UUID = req.parameters.get("save_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchAccessibleProfile(req: req, session: session, pool: pool),
          let save = try await fetchProfileSave(userId: profile.userId, profile: profile, saveId: saveId, pool: pool) else {
        return try await profileNotFoundResponse(session: session, req: req, pool: pool, error: "Profile or save not found.")
    }
    let sequenceId = save.sequentialId
    let nav = profileNavigationContext(session: session, profile: profile)
    try await deleteProfileSave(userId: profile.userId, profile: profile, saveId: save.id, pool: pool)
    return req.redirect(to: "\(nav.sequenceBasePath)/\(sequenceId.uuidString)", redirectType: .normal)
}
