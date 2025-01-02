import ArgumentParser
import Hummingbird
import App

struct HummingbirdCommand: ParsableCommand {
    
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"
    
    @Option(name: .shortAndLong)
    var port: Int = 8080
    
    func run() throws {
        let app = HBApplication(
            configuration: .init(
                address: .hostname(hostname, port: port),
                serverName: "Hummingbird"
            )
        )
        try app.configure()
        try app.start()
        app.wait()
    }
}

HummingbirdCommand.main()
