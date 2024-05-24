//
//  HomePage.swift
//  
//
//  Created by Isaac Paul on 5/23/24.
//

import Vapor
import Plot

struct HomePage: Plot.Component, IHtmlHeader {
    func header() -> String {
        "Save Cloud - Home"
    }
    
    func css() -> String {
        "/style.css"
    }
    
    
    let admin:Bool
    var body: Component {
        Div {
            NavBar(admin: admin)
        }
    }
}
