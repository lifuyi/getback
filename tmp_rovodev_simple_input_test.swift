import SwiftUI

@available(macOS 13.0, *)
struct SimpleInputTest: View {
    @Environment(\.dismiss) private var dismiss
    @State private var testText = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Simple Input Test")
                .font(.title)
            
            TextField("Type here to test", text: $testText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300, height: 40)
            
            Text("Current text: '\(testText)'")
                .foregroundColor(.secondary)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Button("OK") {
                    print("Text entered: \(testText)")
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
        .frame(width: 400, height: 200)
    }
}