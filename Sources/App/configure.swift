import Vapor
import NIOSSL
public let defaultCipherSuites = [
    "ECDH+AESGCM",
    "ECDH+CHACHA20",
    "DH+AESGCM",
    "DH+CHACHA20",
    "ECDH+AES256",
    "DH+AES256",
    "ECDH+AES128",
    "DH+AES",
    "RSA+AESGCM",
    "RSA+AES",
    "!aNULL",
    "!eNULL",
    "!MD5",
    ].joined(separator: ":")
// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    print("Public Dir: \(app.directory.publicDirectory)")
    // Enable TLS.
    app.http.server.configuration.responseCompression = .enabled
    var tlsConfiguration:TLSConfiguration = .makeServerConfiguration(
        certificateChain: try NIOSSLCertificate.fromPEMFile("\(app.directory.publicDirectory)localhost_root.pem").map { .certificate($0) },
        privateKey: .file("\(app.directory.publicDirectory)/localhost_key.pem")
    )
    tlsConfiguration.certificateVerification = .noHostnameVerification
    
    app.http.server.configuration.tlsConfiguration = tlsConfiguration
    
    tryOrLog(SourceInfo(type:#file), {try Database.initDB()})
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(app.sessions.middleware)
    // register routes
    try routes(app)
}
