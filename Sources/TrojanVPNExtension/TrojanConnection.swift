#if os(iOS)
import Foundation
import Network
import NetworkExtension
import CryptoKit
import UIKit

protocol TrojanConnectionDelegate: AnyObject {
    func trojanConnection(_ connection: TrojanConnection, didReceivePacket packet: Data, protocolFamily: NSNumber)
    func trojanConnection(_ connection: TrojanConnection, didDisconnectWithError error: Error?)
}

class TrojanConnection {
    weak var delegate: TrojanConnectionDelegate?
    
    private let serverAddress: String
    private let port: Int
    private let password: String
    private let sni: String?
    private let packetFlow: NEPacketFlow
    
    // Enhanced configuration
    private let enableUDP: Bool
    private let enableWebSocket: Bool
    private let enableMux: Bool
    private let enableFastOpen: Bool
    
    private var tcpConnection: NWConnection?
    private var udpConnection: NWConnection?
    private var isConnected = false
    private let queue = DispatchQueue(label: "trojan.connection")
    
    // Connection multiplexing
    private var connectionPool: [NWConnection] = []
    private let maxConnections = 4
    private var currentConnectionIndex = 0
    
    init(serverAddress: String, port: Int, password: String, sni: String?, packetFlow: NEPacketFlow, config: [String: Any] = [:]) {
        self.serverAddress = serverAddress
        self.port = port
        self.password = password
        self.sni = sni
        self.packetFlow = packetFlow
        
        // Parse enhanced configuration
        self.enableUDP = config["enableUDP"] as? Bool ?? false
        self.enableWebSocket = config["enableWebSocket"] as? Bool ?? false
        self.enableMux = config["mux"] as? Bool ?? false
        self.enableFastOpen = config["fastOpen"] as? Bool ?? false
    }
    
    func connect(completion: @escaping (Error?) -> Void) {
        if enableMux {
            connectWithMultiplexing(completion: completion)
        } else {
            connectSingleConnection(completion: completion)
        }
    }
    
    private func connectSingleConnection(completion: @escaping (Error?) -> Void) {
        // Create TLS options
        let tlsOptions = NWProtocolTLS.Options()
        
        // Configure SNI if provided
        if let sni = sni {
            sec_protocol_options_set_tls_server_name(tlsOptions.securityProtocolOptions, sni)
        }
        
        // Enable TLS 1.3 for better performance
        sec_protocol_options_set_min_tls_protocol_version(tlsOptions.securityProtocolOptions, tls_protocol_version_t(rawValue: 1)!)
        
        // Create TCP options
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 30
        tcpOptions.keepaliveInterval = 15
        tcpOptions.keepaliveCount = 3
        
        // Enable TCP Fast Open if supported
        if enableFastOpen {
            tcpOptions.enableFastOpen = true
        }
        
        // Create connection parameters
        let parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)
        parameters.includePeerToPeer = false
        parameters.preferNoProxies = true
        
        // Create connection
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(serverAddress), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
        tcpConnection = NWConnection(to: endpoint, using: parameters)
        
        tcpConnection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.handleTCPConnectionReady(completion: completion)
            case .failed(let error):
                completion(error)
            case .cancelled:
                self?.delegate?.trojanConnection(self!, didDisconnectWithError: nil)
            default:
                break
            }
        }
        
        tcpConnection?.start(queue: queue)
        
        // Setup UDP connection if enabled
        if enableUDP {
            setupUDPConnection()
        }
    }
    
    private func connectWithMultiplexing(completion: @escaping (Error?) -> Void) {
        let group = DispatchGroup()
        var errors: [Error] = []
        
        for i in 0..<maxConnections {
            group.enter()
            
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(i) * 0.1) {
                self.createPooledConnection { error in
                    if let error = error {
                        errors.append(error)
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: queue) {
            if self.connectionPool.isEmpty {
                let error = errors.first ?? NSError(domain: "TrojanConnection", code: -1, userInfo: [NSLocalizedDescriptionKey: "All connections failed"])
                completion(error)
            } else {
                self.isConnected = true
                completion(nil)
            }
        }
    }
    
    private func createPooledConnection(completion: @escaping (Error?) -> Void) {
        let tlsOptions = NWProtocolTLS.Options()
        
        if let sni = sni {
            sec_protocol_options_set_tls_server_name(tlsOptions.securityProtocolOptions, sni)
        }
        
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 30
        
        let parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(serverAddress), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
        let connection = NWConnection(to: endpoint, using: parameters)
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.connectionPool.append(connection)
                self.sendTrojanHandshake(to: connection) { error in
                    completion(error)
                }
            case .failed(let error):
                completion(error)
            default:
                break
            }
        }
        
        connection.start(queue: queue)
    }
    
    private func setupUDPConnection() {
        let udpOptions = NWProtocolUDP.Options()
        let parameters = NWParameters(dtls: nil, udp: udpOptions)
        
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(serverAddress), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
        udpConnection = NWConnection(to: endpoint, using: parameters)
        
        udpConnection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("UDP connection established")
                self?.startUDPReceiving()
            case .failed(let error):
                print("UDP connection failed: \(error)")
            default:
                break
            }
        }
        
        udpConnection?.start(queue: queue)
    }
    
    private func handleTCPConnectionReady(completion: @escaping (Error?) -> Void) {
        guard let connection = tcpConnection else {
            completion(NSError(domain: "TrojanConnection", code: -1, userInfo: [NSLocalizedDescriptionKey: "TCP connection not available"]))
            return
        }
        
        sendTrojanHandshake(to: connection) { [weak self] error in
            if let error = error {
                completion(error)
            } else {
                self?.isConnected = true
                self?.startTCPReceiving()
                completion(nil)
            }
        }
    }
    
    private func sendTrojanHandshake(to connection: NWConnection, completion: @escaping (Error?) -> Void) {
        // Send Trojan handshake
        let handshake = createTrojanHandshake()
        
        connection.send(content: handshake, completion: .contentProcessed { error in
            completion(error)
        })
    }
    
    private func createTrojanHandshake() -> Data {
        // Create SHA224 hash of password
        let passwordData = password.data(using: .utf8) ?? Data()
        let hash = SHA256.hash(data: passwordData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        // For simplicity, we'll use the first 56 characters (SHA224 equivalent)
        let trojanHash = String(hashString.prefix(56))
        
        // Trojan protocol format: hash + CRLF + SOCKS5 request
        var handshake = Data()
        handshake.append(trojanHash.data(using: .utf8) ?? Data())
        handshake.append(Data([0x0D, 0x0A])) // CRLF
        
        // SOCKS5 CONNECT request (simplified for tunnel mode)
        // This is a basic implementation - you may need to enhance this
        let socks5Request = Data([
            0x01, // CONNECT command
            0x01, // IPv4 address type
            0x00, 0x00, 0x00, 0x00, // 0.0.0.0 (will be replaced with actual destination)
            0x00, 0x00 // Port 0 (will be replaced with actual port)
        ])
        
        handshake.append(socks5Request)
        handshake.append(Data([0x0D, 0x0A])) // CRLF
        
        return handshake
    }
    
    private func startTCPReceiving() {
        tcpConnection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, context, isComplete, error in
            if let error = error {
                self?.delegate?.trojanConnection(self!, didDisconnectWithError: error)
                return
            }
            
            if let data = data, !data.isEmpty {
                self?.processReceivedTCPData(data)
            }
            
            if !isComplete {
                self?.startTCPReceiving()
            }
        }
    }
    
    private func startUDPReceiving() {
        udpConnection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, context, isComplete, error in
            if let error = error {
                print("UDP receive error: \(error)")
                return
            }
            
            if let data = data, !data.isEmpty {
                self?.processReceivedUDPData(data)
            }
            
            if !isComplete {
                self?.startUDPReceiving()
            }
        }
    }
    
    private func processReceivedTCPData(_ data: Data) {
        // Parse received data and extract packets
        var offset = 0
        
        while offset < data.count {
            // Try to extract IP packet (IPv4 or IPv6)
            if offset + 1 <= data.count {
                let versionAndHeaderLength = data[offset]
                let version = (versionAndHeaderLength >> 4) & 0x0F
                
                if version == 4 { // IPv4
                    if let packet = extractIPv4Packet(from: data, at: offset) {
                        delegate?.trojanConnection(self, didReceivePacket: packet.data, protocolFamily: NSNumber(value: AF_INET))
                        offset += packet.length
                        continue
                    }
                } else if version == 6 { // IPv6
                    if let packet = extractIPv6Packet(from: data, at: offset) {
                        delegate?.trojanConnection(self, didReceivePacket: packet.data, protocolFamily: NSNumber(value: AF_INET6))
                        offset += packet.length
                        continue
                    }
                }
            }
            
            // If we can't parse as IP packet, skip this byte and try next
            offset += 1
        }
    }
    
    private func processReceivedUDPData(_ data: Data) {
        // Process UDP packets received from server
        // Trojan UDP format: [Address Type][Address][Port][Length][Data]
        
        guard let unwrapped = TrojanProtocol.unwrapUDPPacket(data) else {
            print("Failed to unwrap UDP packet")
            return
        }
        
        // Create UDP packet and send to packet flow
        let packet = unwrapped.packet
        delegate?.trojanConnection(self, didReceivePacket: packet, protocolFamily: NSNumber(value: AF_INET))
    }
    
    private func extractIPv4Packet(from data: Data, at offset: Int) -> (data: Data, length: Int)? {
        guard offset + 20 <= data.count else { return nil } // Minimum IPv4 header size
        
        let versionAndHeaderLength = data[offset]
        let headerLength = Int(versionAndHeaderLength & 0x0F) * 4
        
        guard offset + headerLength + 2 <= data.count else { return nil }
        
        let totalLength = Int(data[offset + 2]) << 8 | Int(data[offset + 3])
        
        guard offset + totalLength <= data.count else { return nil }
        
        let packet = data.subdata(in: offset..<(offset + totalLength))
        return (data: packet, length: totalLength)
    }
    
    private func extractIPv6Packet(from data: Data, at offset: Int) -> (data: Data, length: Int)? {
        guard offset + 40 <= data.count else { return nil } // IPv6 header size
        
        let payloadLength = Int(data[offset + 4]) << 8 | Int(data[offset + 5])
        let totalLength = 40 + payloadLength
        
        guard offset + totalLength <= data.count else { return nil }
        
        let packet = data.subdata(in: offset..<(offset + totalLength))
        return (data: packet, length: totalLength)
    }
    
    func sendPacket(_ packet: Data, protocolFamily: NSNumber) {
        guard isConnected else { return }
        
        // Parse packet to determine if it's TCP or UDP
        if let parsedPacket = PacketParser.parseIPPacket(packet) {
            if parsedPacket.isUDP && enableUDP {
                sendUDPPacket(packet, parsedPacket: parsedPacket)
            } else {
                sendTCPPacket(packet)
            }
        } else {
            // Fallback to TCP
            sendTCPPacket(packet)
        }
    }
    
    private func sendTCPPacket(_ packet: Data) {
        let connection = enableMux ? getNextConnection() : tcpConnection
        
        connection?.send(content: packet, completion: .contentProcessed { [weak self] error in
            if let error = error {
                self?.delegate?.trojanConnection(self!, didDisconnectWithError: error)
            }
        })
    }
    
    private func sendUDPPacket(_ packet: Data, parsedPacket: IPPacket) {
        guard let udpConnection = udpConnection else {
            // Fallback to TCP if UDP not available
            sendTCPPacket(packet)
            return
        }
        
        // Extract destination info for UDP wrapping
        let destinationIP = parsedPacket.destinationAddress
        let addressType: TrojanProtocol.SOCKS5AddressType = parsedPacket.isIPv4 ? .ipv4 : .ipv6
        
        // Extract port from UDP header (simplified)
        var destinationPort: UInt16 = 0
        if parsedPacket.payload.count >= 4 {
            destinationPort = UInt16(parsedPacket.payload[2]) << 8 | UInt16(parsedPacket.payload[3])
        }
        
        // Wrap UDP packet according to Trojan protocol
        let wrappedPacket = TrojanProtocol.wrapUDPPacket(
            packet,
            destinationAddress: destinationIP,
            destinationPort: destinationPort,
            addressType: addressType
        )
        
        udpConnection.send(content: wrappedPacket, completion: .contentProcessed { error in
            if let error = error {
                print("UDP send error: \(error)")
            }
        })
    }
    
    private func getNextConnection() -> NWConnection? {
        guard !connectionPool.isEmpty else { return tcpConnection }
        
        let connection = connectionPool[currentConnectionIndex]
        currentConnectionIndex = (currentConnectionIndex + 1) % connectionPool.count
        return connection
    }
    
    func disconnect() {
        isConnected = false
        
        // Cancel all connections
        tcpConnection?.cancel()
        tcpConnection = nil
        
        udpConnection?.cancel()
        udpConnection = nil
        
        // Cancel pooled connections
        for connection in connectionPool {
            connection.cancel()
        }
        connectionPool.removeAll()
        
        currentConnectionIndex = 0
    }
}
#endif