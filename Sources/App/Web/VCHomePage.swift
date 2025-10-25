//
//  HomePage.swift
//  
//
//  Created by Isaac Paul on 5/23/24.
//

import Vapor
import HRW

class VCHomePage : HomePage {
    
    public init(isAdmin:Bool) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: isAdmin).rootNode)
    }
}
