import Vapor
import HRW

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
