import Foundation
import Network
import NetworkExtension
import CryptoKit

// MARK: - TrojanConnection Delegate
public protocol TrojanConnectionDelegate: AnyObject {
    func trojanConnection(_ connection: TrojanConnection, didReceivePacket packet: Data, protocolFamily: NSNumber)
    func trojanConnection(_ connection: TrojanConnection, didDisconnectWithError error: Error?)
}

// MARK: - TrojanConnection Implementation
public class TrojanConnection {
    
    // MARK: - Properties
    public weak var delegate: TrojanConnectionDelegate?
    
    private let serverAddress: String
    private let port: Int
    private let password: String
    private let sni: String?
    private let packetFlow: NEPacketTunnelFlow
    private let config: [String: Any]
    
    private var connection: NWConnection?
    private var isConnected = false
    private let queue = DispatchQueue(label: "TrojanConnection")
    
    // MARK: - Initialization
    public init(serverAddress: String, port: Int, password: String, sni: String?, packetFlow: NEPacketTunnelFlow, config: [String: Any]) {
        self.serverAddress = serverAddress
        self.port = port
        self.password = password
        self.sni = sni
        self.packetFlow = packetFlow
        self.config = config
    }
    
    // MARK: - Connection Management
    public func connect(completion: @escaping (Error?) -> Void) {
        guard let portNumber = NWEndpoint.Port(rawValue: UInt16(port)) else {
            completion(TrojanError.invalidPort)
            return
        }
        
        let host = NWEndpoint.Host(serverAddress)
        let tcpOptions = NWProtocolTCP.Options()
        
        // Configure TLS if needed
        let tlsOptions = NWProtocolTLS.Options()
        if let sni = sni {
            sec_protocol_options_set_tls_server_name(tlsOptions.securityProtocolOptions, sni)
        }
        
        // Create secure connection
        let parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)
        connection = NWConnection(host: host, port: portNumber, using: parameters)
        
        connection?.stateUpdateHandler = { [weak self] state in
            self?.handleConnectionState(state, completion: completion)
        }
        
        connection?.start(queue: queue)
    }
    
    public func disconnect() {
        isConnected = false
        connection?.cancel()
        connection = nil
    }
    
    // MARK: - Data Handling
    public func sendPacket(_ packet: Data, protocolFamily: NSNumber) {
        guard isConnected, let connection = connection else { return }
        
        // Wrap packet in Trojan protocol
        let trojanPacket = wrapInTrojanProtocol(packet)
        
        connection.send(content: trojanPacket, completion: .contentProcessed { error in
            if let error = error {
                print("Failed to send packet: \(error)")
            }
        })
    }
    
    // MARK: - Private Methods
    private func handleConnectionState(_ state: NWConnection.State, completion: @escaping (Error?) -> Void) {
        switch state {
        case .ready:
            print("✅ TrojanConnection established to \(serverAddress):\(port)")
            isConnected = true
            
            // Perform Trojan handshake
            performTrojanHandshake { [weak self] error in
                if let error = error {
                    completion(error)
                } else {
                    completion(nil)
                    self?.startReceiving()
                }
            }
            
        case .failed(let error):
            print("❌ TrojanConnection failed: \(error)")
            isConnected = false
            completion(error)
            
        case .cancelled:
            print("🔄 TrojanConnection cancelled")
            isConnected = false
            
        case .waiting(let error):
            print("⏳ TrojanConnection waiting: \(error)")
            
        default:
            break
        }
    }
    
    private func performTrojanHandshake(completion: @escaping (Error?) -> Void) {
        // Create Trojan authentication header
        let authData = createTrojanAuth()
        
        connection?.send(content: authData, completion: .contentProcessed { error in
            if let error = error {
                completion(TrojanError.handshakeFailed(error))
            } else {
                completion(nil)
            }
        })
    }
    
    private func createTrojanAuth() -> Data {
        // Generate SHA224 hash of password
        let passwordData = password.data(using: .utf8) ?? Data()
        let hash = SHA256.hash(data: passwordData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        // Trojan protocol: [HASH][CRLF][CMD][ATYP][ADDR][PORT][CRLF]
        var authData = Data()
        authData.append(hashString.data(using: .utf8) ?? Data())
        authData.append(Data([0x0D, 0x0A])) // CRLF
        authData.append(Data([0x01])) // CMD: CONNECT
        authData.append(Data([0x03])) // ATYP: DOMAIN
        
        // Add dummy target (will be overridden by actual packets)
        let target = "www.google.com"
        authData.append(Data([UInt8(target.count)]))
        authData.append(target.data(using: .utf8) ?? Data())
        authData.append(Data([0x00, 0x50])) // Port 80
        authData.append(Data([0x0D, 0x0A])) // CRLF
        
        return authData
    }
    
    private func wrapInTrojanProtocol(_ packet: Data) -> Data {
        // For subsequent packets, just send raw data
        // The initial handshake establishes the tunnel
        return packet
    }
    
    private func startReceiving() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                // Parse received data and extract original packets
                self?.processReceivedData(data)
            }
            
            if let error = error {
                self?.delegate?.trojanConnection(self!, didDisconnectWithError: error)
                return
            }
            
            if !isComplete {
                self?.startReceiving() // Continue receiving
            }
        }
    }
    
    private func processReceivedData(_ data: Data) {
        // In a real implementation, you'd parse the Trojan protocol response
        // For now, assume it's raw packet data
        delegate?.trojanConnection(self, didReceivePacket: data, protocolFamily: NSNumber(value: AF_INET))
    }
}

// MARK: - TrojanError
public enum TrojanError: Error, LocalizedError {
    case invalidPort
    case handshakeFailed(Error)
    case connectionFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidPort:
            return "Invalid port number"
        case .handshakeFailed(let error):
            return "Trojan handshake failed: \(error.localizedDescription)"
        case .connectionFailed(let error):
            return "Connection failed: \(error.localizedDescription)"
        }
    }
}