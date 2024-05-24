import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    print("Public Dir: \(app.directory.publicDirectory)")
    
    tryOrLog(SourceInfo(type:#file), {try Database.initDB()})
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(app.sessions.middleware)
    // register routes
    try routes(app)
}
