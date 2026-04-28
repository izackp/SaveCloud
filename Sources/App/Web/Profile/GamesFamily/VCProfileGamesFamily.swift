import Vapor
import HRW

final class VCProfileGameSaveRow: ProfileGameSaveRow {
    init(group: ProfileGameSaveSequenceGroup, downloadPath: String, deletePath: String, sequencePath: String) throws {
        try super.init()
        let save = group.latestSave
        save_name.addChild(HTMLText(content: save.name ?? "Untitled save"))
        save_count.addChild(HTMLText(content: group.saves.count == 1 ? "1 save in sequence" : "\(group.saves.count) saves in sequence"))
        sequence_link.href = URL(string: sequencePath)
        source_device.addChild(HTMLText(content: save.sourceDevice ?? "Unknown device"))
        file_size.addChild(HTMLText(content: profileFileSizeText(save.fileSize)))
        let saveDate = save.date ?? save.updatedAt
        save_date.addChild(HTMLText(content: fullProfileSaveDateText(saveDate)))
        download_link.href = URL(string: downloadPath)
        delete_link.href = URL(string: deletePath)
    }
}

final class VCProfileGameSaveVersionGroup: ProfileGameSaveVersionGroup {
    init(versionGroup: ProfileGameSaveVersionGroupData, saveBasePath: String, deleteSequenceBasePath: String, sequenceBasePath: String) throws {
        try super.init()
        version_title.addChild(HTMLText(content: profileGameVersionText(versionGroup.game)))
        let sequenceCopy = versionGroup.sequenceGroups.count == 1 ? "1 save sequence" : "\(versionGroup.sequenceGroups.count) save sequences"
        let saveCopy = versionGroup.saves.count == 1 ? "1 save" : "\(versionGroup.saves.count) saves"
        version_summary.addChild(HTMLText(content: "\(sequenceCopy), \(saveCopy)"))
        version_game_link.href = URL(string: "/games/\(versionGroup.game.id.uuidString)")
        for group in versionGroup.sequenceGroups {
            saves_list.children.append(try VCProfileGameSaveRow(
                group: group,
                downloadPath: "\(saveBasePath)/\(group.latestSave.id.uuidString)",
                deletePath: "\(deleteSequenceBasePath)/\(group.sequentialId.uuidString)/delete",
                sequencePath: "\(sequenceBasePath)/\(group.sequentialId.uuidString)"
            ).rootNode)
        }
    }
}

final class VCProfileGameSaveDownloadRow: ProfileGameSaveDownloadRow {
    init(save: Save, downloadPath: String) throws {
        try super.init()
        save_name.addChild(HTMLText(content: save.name ?? "Untitled save"))
        let saveDate = save.date ?? save.updatedAt
        save_date.addChild(HTMLText(content: fullProfileSaveDateText(saveDate)))
        download_link.href = URL(string: downloadPath)
    }
}

final class VCProfileGameSavesPage: ProfileGameSavesPage {
    init(session: AuthSession, profile: UserProfile, familyData: ProfileGameFamilySavesData, rootLabel: String, rootLinkPath: String, backLinkPath: String, downloadAllPath: String, deleteAllPath: String, saveBasePath: String, deleteSequenceBasePath: String, sequenceBasePath: String, error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        if let error {
            p_error.addChild(HTMLText(content: error))
            p_error.globalAttributes[.style] = ""
        }
        breadcrumb_root_label.addChild(HTMLText(content: rootLabel))
        breadcrumb_root_link.href = URL(string: rootLinkPath)
        breadcrumb_profile_link.href = URL(string: backLinkPath)
        breadcrumb_profile_name.addChild(HTMLText(content: profile.name))
        breadcrumb_game_name.addChild(HTMLText(content: familyData.displayGame.name))
        let summaryCopy = familyData.saves.count == 1 ? "1 save" : "\(familyData.saves.count) saves"
        summary_text.addChild(HTMLText(content: summaryCopy))
        game_name.addChild(HTMLText(content: familyData.displayGame.name))
        game_detail_link.href = URL(string: "/games/\(familyData.displayGame.id.uuidString)")
        download_all_link.href = URL(string: downloadAllPath)
        delete_all_link.href = URL(string: deleteAllPath)
        if familyData.saves.isEmpty {
            empty_text.globalAttributes[.style] = ""
        } else {
            for versionGroup in familyData.versionGroups {
                version_groups.children.append(try VCProfileGameSaveVersionGroup(
                    versionGroup: versionGroup,
                    saveBasePath: saveBasePath,
                    deleteSequenceBasePath: deleteSequenceBasePath,
                    sequenceBasePath: sequenceBasePath
                ).rootNode)
            }
        }
        back_link.href = URL(string: backLinkPath)
    }
}

final class VCProfileGameSavesDownloadPage: ProfileGameSavesDownloadPage {
    init(session: AuthSession, familyData: ProfileGameFamilySavesData, saveBasePath: String, backLinkPath: String) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        title.addChild(HTMLText(content: "Download \(familyData.displayGame.name) latest saves"))
        let latestSaves = familyData.versionGroups.flatMap { $0.sequenceGroups.map(\.latestSave) }
        let summaryCopy = latestSaves.count == 1 ? "1 latest save available" : "\(latestSaves.count) latest saves available"
        summary_text.addChild(HTMLText(content: summaryCopy))
        for save in latestSaves.sorted(by: isMoreRecent(_:than:)) {
            download_list.children.append(try VCProfileGameSaveDownloadRow(save: save, downloadPath: "\(saveBasePath)/\(save.id.uuidString)").rootNode)
        }
        back_link.href = URL(string: backLinkPath)
    }
}

final class VCDeleteProfileGameSavesPage: DeleteProfileGameSavesPage {
    init(session: AuthSession, profile: UserProfile, familyData: ProfileGameFamilySavesData, deletePath: String, cancelPath: String, sequenceGroup: ProfileGameSaveSequenceGroup?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        let isSequenceDelete = sequenceGroup != nil
        title.addChild(HTMLText(content: isSequenceDelete ? "Delete Save Sequence" : "Delete All Saves"))
        message.addChild(HTMLText(content: isSequenceDelete ? "This will permanently delete every save in this sequence." : "This will permanently delete every save for this game family in this profile."))
        game_name.addChild(HTMLText(content: familyData.displayGame.name))
        profile_name.addChild(HTMLText(content: profile.name))
        if let sequenceGroup {
            let copy = sequenceGroup.saves.count == 1 ? "1 save" : "\(sequenceGroup.saves.count) saves"
            save_count.addChild(HTMLText(content: copy))
        } else {
            save_count.addChild(HTMLText(content: familyData.saves.count == 1 ? "1 save" : "\(familyData.saves.count) saves"))
        }
        delete_form.action = URL(string: deletePath)
        delete_button.addChild(HTMLText(content: isSequenceDelete ? "Delete Sequence" : "Delete All Saves"))
        cancel_link.href = URL(string: cancelPath)
    }
}

@Sendable func userProfileGameSavesPage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try expiredSessionResponse()
    }
    guard let familyId: UUID = req.parameters.get("family_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchAccessibleProfile(req: req, session: session, pool: pool) else {
        return try await profileNotFoundResponse(session: session, req: req, pool: pool, error: "Profile not found.")
    }
    let nav = profileNavigationContext(session: session, profile: profile)
    guard let familyData = try await fetchProfileGameFamily(userId: profile.userId, profile: profile, familyId: familyId, pool: pool) else {
        let summaries = try await fetchProfileGameSummaries(userId: profile.userId, profile: profile, pool: pool)
        let state = ProfileGamesPageState(req: req)
        let filteredSummaries = filterProfileGameSummaries(summaries, state: state)
        let sortedSummaries = sortProfileGameSummaries(filteredSummaries, state: state)
        let (pageSummaries, hasNextPage) = pageProfileGameSummaries(sortedSummaries, state: state)
        let listPath = "\(nav.basePath)/games"
        return try VCProfileGamesPage(session: session, profile: profile, summaries: pageSummaries, totalCount: filteredSummaries.count, state: state, hasNextPage: hasNextPage, listPath: listPath, gameLinkBasePath: "\(nav.basePath)/games-family", backLinkPath: nav.backLinkPath, error: "Game family not found.").rootNode.response()
    }
    let savesPath = nav.familyPath(familyId)
    return try VCProfileGameSavesPage(session: session, profile: profile, familyData: familyData, rootLabel: nav.rootLabel, rootLinkPath: nav.rootLinkPath, backLinkPath: "\(nav.basePath)/games", downloadAllPath: "\(savesPath)/saves/download", deleteAllPath: "\(savesPath)/saves/delete", saveBasePath: nav.savesBasePath, deleteSequenceBasePath: "\(savesPath)/saves", sequenceBasePath: nav.sequenceBasePath, error: nil).rootNode.response()
}

@Sendable func userProfileGameSavesDownloadPage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try expiredSessionResponse()
    }
    guard let familyId: UUID = req.parameters.get("family_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchAccessibleProfile(req: req, session: session, pool: pool),
          let familyData = try await fetchProfileGameFamily(userId: profile.userId, profile: profile, familyId: familyId, pool: pool) else {
        return try await profileNotFoundResponse(session: session, req: req, pool: pool, error: "Profile or game not found.")
    }
    let nav = profileNavigationContext(session: session, profile: profile)
    return try VCProfileGameSavesDownloadPage(session: session, familyData: familyData, saveBasePath: nav.savesBasePath, backLinkPath: nav.familyPath(familyId)).rootNode.response()
}

@Sendable func deleteUserProfileGameSavesPage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try expiredSessionResponse()
    }
    guard let familyId: UUID = req.parameters.get("family_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchAccessibleProfile(req: req, session: session, pool: pool),
          let familyData = try await fetchProfileGameFamily(userId: profile.userId, profile: profile, familyId: familyId, pool: pool) else {
        return try await profileNotFoundResponse(session: session, req: req, pool: pool, error: "Profile or game not found.")
    }
    let nav = profileNavigationContext(session: session, profile: profile)
    let sequentialId: UUID? = req.parameters.get("sequential_id")
    let sequenceGroup = sequentialId.flatMap { findSequenceGroup($0, in: familyData) }
    if sequentialId != nil && sequenceGroup == nil {
        throw Abort(.notFound)
    }
    let basePath = nav.familyPath(familyId)
    let deletePath = sequentialId.map { "\(basePath)/saves/\($0.uuidString)/delete" } ?? "\(basePath)/saves/delete"
    return try VCDeleteProfileGameSavesPage(session: session, profile: profile, familyData: familyData, deletePath: deletePath, cancelPath: basePath, sequenceGroup: sequenceGroup).rootNode.response()
}

@Sendable func deleteUserProfileGameSaves(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try expiredSessionResponse()
    }
    guard let familyId: UUID = req.parameters.get("family_id") else {
        throw Abort(.badRequest)
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchAccessibleProfile(req: req, session: session, pool: pool) else {
        return try await profileNotFoundResponse(session: session, req: req, pool: pool, error: "Profile not found.")
    }
    let sequentialId: UUID? = req.parameters.get("sequential_id")
    let nav = profileNavigationContext(session: session, profile: profile)
    try await deleteProfileGameFamilySaves(userId: profile.userId, profile: profile, familyId: familyId, sequentialId: sequentialId, pool: pool)
    return req.redirect(to: nav.familyPath(familyId), redirectType: .normal)
}
