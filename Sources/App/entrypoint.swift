import Vapor
import Logging
import HRW

@main
enum Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        
        let app = try await Application.make(env)
        
        do {
            try await configure(app)
        } catch {
            app.logger.report(error: error)
            try await app.asyncShutdown()
            throw error
        }
        IHtmlNodeContainerUtility.sharedInstance.defaultBaseDir = "/Users/isaacpaul/Projects/swift-projects/SaveCloud/SaveCloud/Sources/App"
        //IHtmlNodeContainerUtility.sharedInstance.defaultBaseDir = app.directory.viewsDirectory
        try await app.execute()
        try await app.asyncShutdown()
    }
}
