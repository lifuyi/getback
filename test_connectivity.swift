#!/usr/bin/env swift

import Foundation
import Network

print("🔍 Testing connection to chinida.space:443...")

// Test basic connectivity
let serverAddress = "chinida.space"
let port = 443

// Create a simple TCP connection test
let connection = NWConnection(host: serverAddress, port: NWEndpoint.Port(rawValue: UInt16(port))!, using: .tcp)

let semaphore = DispatchSemaphore(value: 0)
var connectionSuccess = false
var connectionError: Error?

connection.stateUpdateHandler = { state in
    switch state {
    case .ready:
        print("✅ TCP connection to \(serverAddress):\(port) successful")
        connectionSuccess = true
        connection.cancel()
        semaphore.signal()
    case .failed(let error):
        print("❌ TCP connection to \(serverAddress):\(port) failed: \(error)")
        connectionError = error
        semaphore.signal()
    case .cancelled:
        if !connectionSuccess && connectionError == nil {
            print("❌ TCP connection to \(serverAddress):\(port) cancelled")
        }
        semaphore.signal()
    default:
        break
    }
}

connection.start(queue: .main)

// Wait for 10 seconds
if semaphore.wait(timeout: .now() + 10) == .timedOut {
    print("❌ Connection test timed out after 10 seconds")
    connection.cancel()
}

// Now test HTTPS connectivity
print("\n🔍 Testing HTTPS connection to https://\(serverAddress):\(port)...")

let url = URL(string: "https://\(serverAddress):\(port)")!
var request = URLRequest(url: url)
request.timeoutInterval = 10.0

let httpsSemaphore = DispatchSemaphore(value: 0)

URLSession.shared.dataTask(with: request) { data, response, error in
    if let error = error {
        print("❌ HTTPS connection to \(serverAddress):\(port) failed: \(error)")
    } else if let httpResponse = response as? HTTPURLResponse {
        print("✅ HTTPS connection to \(serverAddress):\(port) successful!")
        print("   Status code: \(httpResponse.statusCode)")
        if let server = httpResponse.allHeaderFields["Server"] as? String {
            print("   Server: \(server)")
        }
    } else {
        print("✅ HTTPS connection to \(serverAddress):\(port) successful!")
    }
    httpsSemaphore.signal()
}.resume()

httpsSemaphore.wait()

print("\n✅ Connection testing completed!")