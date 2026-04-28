import Vapor
import HRW

final class VCProfileDetailPage: ProfileDetailPage {
    init(session: AuthSession, profile: UserProfile, error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        if let error {
            p_error.addChild(HTMLText(content: error))
            p_error.globalAttributes[.style] = ""
        }
        title.addChild(HTMLText(content: profile.name))
        let profileId = profile.id.description
        profile_avatar_container.addChild(HTMLText(content: #"<svg width="120" height="120" data-jdenticon-value="\#(profileId)"></svg>"#))
        profile_id.addChild(HTMLText(content: profile.id.description))
        name.addChild(HTMLText(content: profile.name))
        profile_id_record.addChild(HTMLText(content: profile.id.description))
        back_link.href = URL(string: "/user/profiles")
    }
}
