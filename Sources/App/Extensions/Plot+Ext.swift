//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/10/24.
//

import Plot
import Vapor

extension Plot.Component {
    func wrapHTML(_ title:String, _ css:String) -> HTML {
        return HTML(
            .head(
                .title(title),
                .stylesheet(css)
            ),
            .component(self)
        )
    }
}

extension Plot.Component where Self: IHtmlHeader {
    func wrapHTML() -> HTML {
        return HTML(
            .head(
                .title(self.header()),
                .stylesheet(self.css())
                //.stylesheet("/theme.css")
            ),
            .component(self)
        )
    }
}

extension Response.Body {
    init(html: HTML) {
        self.init(string: html.render(indentedBy: .tabs(1)))
    }
}

extension Response {
    convenience init(_ html: HTML) {
        self.init(status: .ok, headers: ["Content-Type": "text/html"], body: .init(html: html))
    }
}

extension HTML {
    func response() -> Response {
        Response(self)
    }
}

extension HTML: ResponseEncodable {
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        request.eventLoop.makeSucceededFuture(Response(self))
    }
}

extension HTML: AsyncResponseEncodable {
    public func encodeResponse(for request: Request) async -> Response {
        return Response(self)
    }
}
