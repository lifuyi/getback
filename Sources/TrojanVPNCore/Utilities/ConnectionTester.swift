import Foundation
import Network
import TrojanVPNModels

public class ConnectionTester {
    public static let shared = ConnectionTester()
    
    private init() {}
    
    public struct TestResult {
        public let isSuccessful: Bool
        public let latency: TimeInterval
        public let error: Error?
        public let details: String
        
        public init(isSuccessful: Bool, latency: TimeInterval, error: Error? = nil, details: String) {
            self.isSuccessful = isSuccessful
            self.latency = latency
            self.error = error
            self.details = details
        }
    }
    
    public func testConnection(to profile: ServerProfile, completion: @escaping (TestResult) -> Void) {
        let startTime = Date()
        
        // Test 1: Basic connectivity
        testBasicConnectivity(to: profile) { [weak self] basicResult in
            if !basicResult.isSuccessful {
                completion(basicResult)
                return
            }
            
            // Test 2: Port connectivity
            self?.testPortConnectivity(to: profile) { portResult in
                let totalLatency = Date().timeIntervalSince(startTime)
                
                if portResult.isSuccessful {
                    completion(TestResult(
                        isSuccessful: true,
                        latency: totalLatency,
                        details: "Server is ready for VPN connection"
                    ))
                } else {
                    completion(portResult)
                }
            }
        }
    }
    
    private func testBasicConnectivity(to profile: ServerProfile, completion: @escaping (TestResult) -> Void) {
        guard let url = URL(string: "https://\(profile.serverAddress)") else {
            completion(TestResult(
                isSuccessful: false,
                latency: 0,
                error: NSError(domain: "ConnectionTester", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server address"]),
                details: "Invalid server URL"
            ))
            return
        }
        
        let startTime = Date()
        var request = URLRequest(url: url)
        request.timeoutInterval = 15.0
        request.setValue("TrojanVPN-Test/1.0", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            let latency = Date().timeIntervalSince(startTime)
            
            DispatchQueue.main.async {
                if let error = error {
                    completion(TestResult(
                        isSuccessful: false,
                        latency: latency,
                        error: error,
                        details: "HTTPS connection failed: \(error.localizedDescription)"
                    ))
                } else if let httpResponse = response as? HTTPURLResponse {
                    completion(TestResult(
                        isSuccessful: true,
                        latency: latency,
                        details: "HTTPS successful (Status: \(httpResponse.statusCode))"
                    ))
                } else {
                    completion(TestResult(
                        isSuccessful: true,
                        latency: latency,
                        details: "Server responded successfully"
                    ))
                }
            }
        }.resume()
    }
    
    private func testPortConnectivity(to profile: ServerProfile, completion: @escaping (TestResult) -> Void) {
        let host = NWEndpoint.Host(profile.serverAddress)
        guard let port = NWEndpoint.Port(rawValue: UInt16(profile.port)) else {
            completion(TestResult(
                isSuccessful: false,
                latency: 0,
                error: NSError(domain: "ConnectionTester", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid port"]),
                details: "Invalid port number: \(profile.port)"
            ))
            return
        }
        
        let startTime = Date()
        let connection = NWConnection(host: host, port: port, using: .tcp)
        
        connection.stateUpdateHandler = { (state: NWConnection.State) in
            let latency = Date().timeIntervalSince(startTime)
            
            switch state {
            case .ready:
                connection.cancel()
                DispatchQueue.main.async {
                    completion(TestResult(
                        isSuccessful: true,
                        latency: latency,
                        details: "Port \(profile.port) is open and accessible"
                    ))
                }
            case .failed(let error):
                connection.cancel()
                DispatchQueue.main.async {
                    completion(TestResult(
                        isSuccessful: false,
                        latency: latency,
                        error: error,
                        details: "Port connection failed: \(error.localizedDescription)"
                    ))
                }
            case .cancelled:
                break
            default:
                break
            }
        }
        
        connection.start(queue: DispatchQueue.global())
        
        // Timeout after 10 seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
            switch connection.state {
            case .ready, .cancelled:
                break // Already handled
            case .failed(_):
                break // Already handled
            default:
                connection.cancel()
                DispatchQueue.main.async {
                    completion(TestResult(
                        isSuccessful: false,
                        latency: 10.0,
                        error: NSError(domain: "ConnectionTester", code: -3, userInfo: [NSLocalizedDescriptionKey: "Connection timeout"]),
                        details: "Connection to port \(profile.port) timed out"
                    ))
                }
            }
        }
    }
}