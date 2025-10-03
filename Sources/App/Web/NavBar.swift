//
//  NavBar.swift
//
//
//  Created by Isaac Paul on 5/23/24.
//

import Vapor
import Plot

struct NavBar: Plot.Component {
    let admin:Bool
    var body: Component {
        Navigation() {
            Div() {
                Span("User").class("nav_item").class("nav_text")
                Link(url:"/user/edit") { Span("Update") }.class("nav_item")
                Link(url:"/user/games") { Span("Games") }.class("nav_item")
                Link(url:"/user/saves") { Span("Saves") }.class("nav_item")
            }.class("nav_section").class("user")
            if (admin) {
                Div() {
                    Span("Admin").class("nav_item").class("nav_text")
                    Link(url:"/user/edit_all") { Span("Users") }.class("nav_item")
                    Link(url:"/user/sessions") { Span("Sessions") }.class("nav_item")
                    Link(url:"/games") { Span("Games") }.class("nav_item")
                    Link(url:"/saves") { Span("Saves") }.class("nav_item")
                }.class("nav_section").class("admin")
            }
                
        }.id("sidebar")
    }
}

