//
//  NavBar.swift
//
//
//  Created by Isaac Paul on 5/23/24.
//

import Vapor
import HRW
import System

public extension Application {
    func readHtmlFromFile(_ fileName:String) throws -> [HTMLNode] {
        let directory = self.directory.viewsDirectory
        let fp = FilePath("\(directory)\(fileName)")
        let str = String(decoding: fp)
        guard let xmlReader = XMLParser(str: str) else { throw AppError("Empty String") }
        let rootNodes = try xmlReader.readObjects()
        return rootNodes
    }
}

struct NavBar {
    let binding:NavBarBinding
    let rootNode:Nav
    
    init(_ app:Application, isAdmin:Bool) throws {
        let nodes = try app.readHtmlFromFile("NavBar.html")
        let rootNode = nodes.first as! Nav
        binding = try NavBarBinding(rootNode: rootNode)
        self.rootNode = rootNode
        if (isAdmin) {
            binding.nav_section_admin.globalAttributes[.style] = ""
        }
    }
}

