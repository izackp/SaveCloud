import Vapor
import HRW

final class VCProfileGamesTableRow: ProfileGamesTableRow {
    init(summary: ProfileGameSummary, href: String) throws {
        try super.init()
        game_link.href = URL(string: href)
        game_name.addChild(HTMLText(content: summary.game.name))
        version.addChild(HTMLText(content: summary.game.version.map { "Version \($0)" } ?? "No version"))
        let latestDate = summary.latestSaveDate
        latest_save_date.addChild(HTMLText(content: shortProfileSaveDateText(latestDate)))
        latest_save_date.globalAttributes[.title] = fullProfileSaveDateText(latestDate)
        save_name.addChild(HTMLText(content: summary.latestSave.name ?? "Untitled save"))
    }
}

final class VCProfileGamesPage: ProfileGamesPage {
    init(session: AuthSession, profile: UserProfile, summaries: [ProfileGameSummary], totalCount: Int, state: ProfileGamesPageState, hasNextPage: Bool, listPath: String, gameLinkBasePath: String, backLinkPath: String, error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        if let error {
            p_error.addChild(HTMLText(content: error))
            p_error.globalAttributes[.style] = ""
        }
        let nav = profileNavigationContext(session: session, profile: profile)
        breadcrumb_root_label.addChild(HTMLText(content: nav.rootLabel))
        breadcrumb_root_link.href = URL(string: nav.rootLinkPath)
        breadcrumb_profile_link.href = URL(string: nav.backLinkPath)
        breadcrumb_profile_name.addChild(HTMLText(content: profile.name))
        breadcrumb_games_label.addChild(HTMLText(content: "Games"))
        let profileId = profile.id.description
        profile_avatar_container.addChild(HTMLText(content: #"<svg width="120" height="120" data-jdenticon-value="\#(profileId)"></svg>"#))
        profile_id.addChild(HTMLText(content: profile.name))
        let summaryCopy = totalCount == 1 ? "1 game" : "\(totalCount) games"
        summary_text.addChild(HTMLText(content: summaryCopy))
        search_input.value = state.query
        sort_by_input.value = state.sortBy.rawValue
        asc_input.value = state.sortAscending ? "1" : "0"
        sort_name_link.href = URL(string: "\(listPath)?\(state.sortQueryString(.name))")
        sort_date_link.href = URL(string: "\(listPath)?\(state.sortQueryString(.lastSaveDate))")
        if state.sortBy == .name {
            sort_name_link.globalAttributes[.class_] = "profile-game-sort-button is-active"
        } else {
            sort_date_link.globalAttributes[.class_] = "profile-game-sort-button is-active"
        }
        let startCount = summaries.isEmpty ? 0 : Int(state.page * state.perPage) + 1
        let endCount = Int(state.page * state.perPage) + summaries.count
        let resultCopy = state.query.isEmpty
            ? "Showing \(startCount)-\(endCount) of \(totalCount)"
            : "Showing \(startCount)-\(endCount) of \(totalCount) matches"
        result_count.addChild(HTMLText(content: resultCopy))
        if summaries.isEmpty {
            empty_text.globalAttributes[.style] = ""
        } else {
            for summary in summaries {
                let href = "\(gameLinkBasePath)/\(profileGameFamilyId(summary.game).uuidString)"
                game_list.children.append(try VCProfileGamesTableRow(summary: summary, href: href).rootNode)
            }
        }
        page_text.addChild(HTMLText(content: "Page \(state.page + 1)"))
        if state.page > 0 {
            prev_link.href = URL(string: "\(listPath)?\(state.queryString(page: state.page - 1))")
            prev_link.globalAttributes[.style] = ""
        }
        if hasNextPage {
            next_link.href = URL(string: "\(listPath)?\(state.queryString(page: state.page + 1))")
            next_link.globalAttributes[.style] = ""
        }
        back_link.href = URL(string: backLinkPath)
    }
}

@Sendable func userProfileGamesPage(req: Request) async throws -> Response {
    guard let session = try await req.fetchSession() else {
        return try expiredSessionResponse()
    }
    let pool = DBShared.pool()
    guard let profile = try await fetchAccessibleProfile(req: req, session: session, pool: pool) else {
        return try await profileNotFoundResponse(session: session, req: req, pool: pool, error: "Profile not found.")
    }
    let nav = profileNavigationContext(session: session, profile: profile)
    let summaries = try await fetchProfileGameSummaries(userId: profile.userId, profile: profile, pool: pool)
    let state = ProfileGamesPageState(req: req)
    let filteredSummaries = filterProfileGameSummaries(summaries, state: state)
    let sortedSummaries = sortProfileGameSummaries(filteredSummaries, state: state)
    let (pageSummaries, hasNextPage) = pageProfileGameSummaries(sortedSummaries, state: state)
    let listPath = "\(nav.basePath)/games"
    return try VCProfileGamesPage(session: session, profile: profile, summaries: pageSummaries, totalCount: filteredSummaries.count, state: state, hasNextPage: hasNextPage, listPath: listPath, gameLinkBasePath: "\(nav.basePath)/games-family", backLinkPath: nav.backLinkPath, error: nil).rootNode.response()
}
