import Vapor
import HRW
import GRDB

struct SavesPageState {
    let pageInfo: PageInfo<SaveSortField>

    init(req: Request) throws {
        pageInfo = try req.getPageInfo()
    }

    func queryItems(page: UInt? = nil, sortBy: SaveSortField? = nil, asc: Bool? = nil) -> [String] {
        [
            "page=\(page ?? pageInfo.page)",
            "per_page=\(pageInfo.perPage)",
            "sort_by=\((sortBy ?? pageInfo.sortBy).description)",
            "asc=\((asc ?? pageInfo.sortByAscending) ? "1" : "0")"
        ]
    }

    func queryString(page: UInt? = nil, sortBy: SaveSortField? = nil, asc: Bool? = nil) -> String {
        queryItems(page: page, sortBy: sortBy, asc: asc).joined(separator: "&")
    }

    func sortURL(_ sortBy: SaveSortField) -> String {
        let nextAscending: Bool
        if pageInfo.sortBy == sortBy {
            nextAscending = !pageInfo.sortByAscending
        } else {
            nextAscending = true
        }
        return "/saves?\(queryString(page: 0, sortBy: sortBy, asc: nextAscending))"
    }
}

final class VCSavesTableRow: SavesTableRow {
    init(save: Save) throws {
        try super.init()
        save_id.addChild(HTMLText(content: save.id.uuidString))
        save_id_link.href = URL(string: "/saves/\(save.id.uuidString)")
        user_id.addChild(HTMLText(content: save.userId.description))
        profile_id.addChild(HTMLText(content: save.profileId.description))
        game_meta_id.addChild(HTMLText(content: save.gameMetaId?.uuidString ?? ""))
        if let gameMetaId = save.gameMetaId {
            game_meta_id_link.href = URL(string: "/games/\(gameMetaId.uuidString)")
        } else {
            game_meta_id_link.globalAttributes[.style] = "display:none"
        }
        name.addChild(HTMLText(content: save.name ?? ""))
        source_device.addChild(HTMLText(content: save.sourceDevice ?? ""))
        file_size.addChild(HTMLText(content: "\(save.fileSize)"))
        date.addChild(HTMLText(content: String(describing: save.date)))
        created_at.addChild(HTMLText(content: String(describing: save.createdAt)))
        updated_at.addChild(HTMLText(content: String(describing: save.updatedAt)))
        delete_link.href = URL(string: "/saves/\(save.id.uuidString)/delete")
    }
}

final class VCSavesPage: SavesPage {
    init(session: AuthSession, saves: [Save], state: SavesPageState, hasNextPage: Bool, error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        if let error {
            p_error.addChild(HTMLText(content: error))
            p_error.globalAttributes[.style] = ""
        }
        sort_id_link.href = URL(string: state.sortURL(.id))
        sort_date_link.href = URL(string: state.sortURL(.date))
        sort_created_at_link.href = URL(string: state.sortURL(.createdAt))
        sort_updated_at_link.href = URL(string: state.sortURL(.updatedAt))
        for save in saves {
            table.children.append(try VCSavesTableRow(save: save).rootNode)
        }
        page_text.addChild(HTMLText(content: "Page \(state.pageInfo.page + 1)"))
        if state.pageInfo.page > 0 {
            prev_link.href = URL(string: "/saves?\(state.queryString(page: state.pageInfo.page - 1))")
            prev_link.globalAttributes[.style] = ""
        }
        if hasNextPage {
            next_link.href = URL(string: "/saves?\(state.queryString(page: state.pageInfo.page + 1))")
            next_link.globalAttributes[.style] = ""
        }
    }
}

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

private func adminSaveSession(for req: Request) async throws -> AuthSession? {
    guard let session = try await req.fetchSession(), session.isAdmin else {
        return nil
    }
    return session
}

private func adminSaveAccessDeniedResponse() throws -> Response {
    try VCWelcomePage(users: [], error: "Admin access required.").rootNode.response()
}

private func fetchManagedSave(req: Request, pool: DatabasePool) async throws -> Save? {
    guard let saveId: UUID = req.parameters.get("save_id") else {
        return nil
    }
    return try await pool.read { db in
        try Save.filter(id: saveId).fetchOne(db)
    }
}

@Sendable func savesPage(req: Request) async throws -> Response {
    guard let session = try await adminSaveSession(for: req) else {
        return try adminSaveAccessDeniedResponse()
    }
    let state = try SavesPageState(req: req)
    let pageInfo = state.pageInfo
    let pageSaves = try Save.fetchPaged(pageInfo)
    let nextPageInfo = PageInfo<SaveSortField>(
        page: pageInfo.page + 1,
        perPage: pageInfo.perPage,
        sortBy: pageInfo.sortBy,
        sortByAscending: pageInfo.sortByAscending
    )
    let hasNextPage = !(try Save.fetchPaged(nextPageInfo).isEmpty)
    return try VCSavesPage(session: session, saves: pageSaves, state: state, hasNextPage: hasNextPage, error: nil).rootNode.response()
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
