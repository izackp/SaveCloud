//
//  NavBar.swift
//
//
//  Created by Isaac Paul on 5/23/24.
//

import Vapor
import HRW
import System

class VCNavBar : NavBar {
    init(isAdmin:Bool) throws {
        try super.init()
        if (isAdmin) {
            nav_section_admin.globalAttributes[.style] = ""
        }
    }
}

