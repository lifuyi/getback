#!/usr/bin/env swift

import Foundation

print("🔍 Testing connection to chinida.space:443...")

// Simple URL connection test
let url = URL(string: "https://chinida.space:443")!
var request = URLRequest(url: url)
request.timeoutInterval = 10.0

let semaphore = DispatchSemaphore(value: 0)

URLSession.shared.dataTask(with: request) { data, response, error in
    if let error = error {
        print("❌ Connection to chinida.space:443 failed: \(error)")
        print("   Error description: \(error.localizedDescription)")
    } else if let httpResponse = response as? HTTPURLResponse {
        print("✅ Connection to chinida.space:443 successful!")
        print("   Status code: \(httpResponse.statusCode)")
    } else {
        print("✅ Connection to chinida.space:443 successful!")
    }
    semaphore.signal()
}.resume()

semaphore.wait()

print("\n✅ Connection testing completed!")