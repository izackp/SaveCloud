import Vapor
import HRW

final class VCProfileSequenceSaveRow: ProfileSequenceSaveRow {
    init(save: Save, game: GameMeta?, downloadPath: String, deletePath: String) throws {
        try super.init()
        save_name.addChild(HTMLText(content: save.name ?? "Untitled save"))
        let saveDate = save.date ?? save.updatedAt
        save_date.addChild(HTMLText(content: fullProfileSaveDateText(saveDate)))
        version_text.addChild(HTMLText(content: game.map { profileGameVersionText($0) } ?? "No version recorded"))
        source_device.addChild(HTMLText(content: save.sourceDevice ?? "Unknown device"))
        file_size.addChild(HTMLText(content: profileFileSizeText(save.fileSize)))
        download_link.href = URL(string: downloadPath)
        delete_link.href = URL(string: deletePath)
    }
}

final class VCProfileSaveSequencePage: ProfileSaveSequencePage {
    init(session: AuthSession, profile: UserProfile, sequenceData: ProfileSaveSequenceData, rootLabel: String, rootLinkPath: String, profileLinkPath: String, gameLinkPath: String, backLinkPath: String, saveBasePath: String, error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        if let error {
            p_error.addChild(HTMLText(content: error))
            p_error.globalAttributes[.style] = ""
        }
        breadcrumb_root_label.addChild(HTMLText(content: rootLabel))
        breadcrumb_root_link.href = URL(string: rootLinkPath)
        breadcrumb_profile_name.addChild(HTMLText(content: profile.name))
        breadcrumb_profile_link.href = URL(string: profileLinkPath)
        breadcrumb_game_name.addChild(HTMLText(content: sequenceData.displayGame.name))
        breadcrumb_game_link.href = URL(string: gameLinkPath)
        let saveCopy = sequenceData.saves.count == 1 ? "1 save in sequence" : "\(sequenceData.saves.count) saves in sequence"
        title.addChild(HTMLText(content: saveCopy))
        if sequenceData.saves.isEmpty {
            empty_text.globalAttributes[.style] = ""
        } else {
            for save in sequenceData.saves {
                let game = save.gameMetaId.flatMap { sequenceData.gamesById[$0] }
                saves_list.children.append(try VCProfileSequenceSaveRow(
                    save: save,
                    game: game,
                    downloadPath: "\(saveBasePath)/\(save.id.uuidString)",
                    deletePath: "\(saveBasePath)/\(save.id.uuidString)/delete"
                ).rootNode)
            }
        }
        back_link.href = URL(string: backLinkPath)
    }
}

@Sendable func userProfileSaveSequencePage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try expiredSessionResponse()
    }
    guard let sequenceId: UUID = req.parameters.get("sequence_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchAccessibleProfile(req: req, session: session, pool: pool),
          let sequenceData = try await fetchProfileSaveSequence(userId: profile.userId, profile: profile, sequenceId: sequenceId, pool: pool) else {
        return try await profileNotFoundResponse(session: session, req: req, pool: pool, error: "Profile or save sequence not found.")
    }
    let nav = profileNavigationContext(session: session, profile: profile)
    let familyId = profileGameFamilyId(sequenceData.displayGame)
    return try VCProfileSaveSequencePage(
        session: session,
        profile: profile,
        sequenceData: sequenceData,
        rootLabel: nav.rootLabel,
        rootLinkPath: nav.rootLinkPath,
        profileLinkPath: "\(nav.basePath)/games",
        gameLinkPath: nav.familyPath(familyId),
        backLinkPath: nav.familyPath(familyId),
        saveBasePath: nav.savesBasePath,
        error: nil
    ).rootNode.response()
}
