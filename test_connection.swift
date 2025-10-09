#!/usr/bin/env swift

import Foundation
import Network

// Test connection to chinida.space:443 with password fuyilee
let serverAddress = "chinida.space"
let port = 443
let password = "fuyilee"

print("Testing connection to \(serverAddress):\(port)...")

// Create a URL for testing
let url = URL(string: "https://\(serverAddress):\(port)")!

var request = URLRequest(url: url)
request.timeoutInterval = 10.0

let semaphore = DispatchSemaphore(value: 0)

URLSession.shared.dataTask(with: request) { data, response, error in
    if let error = error {
        print("❌ Connection test failed: \(error.localizedDescription)")
        
        // Try a more basic TCP connection test
        testTCPConnection()
    } else if let httpResponse = response as? HTTPURLResponse {
        if httpResponse.statusCode < 500 {
            print("✅ Connection test successful! Server responded with status code: \(httpResponse.statusCode)")
        } else {
            print("⚠️ Server responded with error status code: \(httpResponse.statusCode)")
        }
    } else {
        print("✅ Connection test successful! Server is reachable.")
    }
    
    semaphore.signal()
}.resume()

semaphore.wait()

func testTCPConnection() {
    print("\nAttempting basic TCP connection test...")
    
    let host = CFHostCreateWithName(nil, serverAddress as CFString).takeRetainedValue()
    CFHostStartInfoResolution(host, .addresses, nil)
    
    var success: DarwinBoolean = false
    if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as? [Data] {
        for address in addresses {
            let sockaddrPtr = address.withUnsafeBytes { $0.bindMemory(to: sockaddr.self) }
            
            var stream: InputStream?
            var writeStream: OutputStream?
            
            InputStream.getStreamsToHost(
                withName: serverAddress,
                port: port,
                inputStream: &stream,
                outputStream: &writeStream
            )
            
            if stream != nil && writeStream != nil {
                if let inputStream = stream, let outputStream = writeStream {
                    inputStream.open()
                    outputStream.open()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        if inputStream.streamStatus == .open {
                            print("✅ TCP connection successful to \(serverAddress):\(port)")
                        } else {
                            print("❌ TCP connection failed to \(serverAddress):\(port)")
                        }
                        
                        inputStream.close()
                        outputStream.close()
                        
                        exit(0)
                    }
                    
                    RunLoop.main.run()
                    return
                }
            }
        }
    }
    
    print("❌ Could not resolve server address: \(serverAddress)")
    exit(1)
}