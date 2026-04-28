//
//  File.swift
//
//
//  Created by Isaac Paul on 5/23/24.
//

import Vapor
import HRW

class VCEditUserPage: EditUserPage {

    public init(user: User, userEditError: String?, passwordEditError: String?) throws {
        try super.init()

        nav_bar.addChild(try VCNavBar(isAdmin: user.isAdmin).rootNode)
        edit_user_form.addChild(try VCEditUserForm(user: user, error: userEditError).rootNode)
        change_password_form.addChild(try VCChangePasswordForm(error: passwordEditError).rootNode)
    }
}
