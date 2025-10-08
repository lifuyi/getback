import Foundation
import CryptoKit

struct TrojanProtocol {
    
    // MARK: - Constants
    static let crlf = Data([0x0D, 0x0A])
    
    // MARK: - SOCKS5 Command Types
    enum SOCKS5Command: UInt8 {
        case connect = 0x01
        case bind = 0x02
        case udpAssociate = 0x03
    }
    
    // MARK: - SOCKS5 Address Types
    enum SOCKS5AddressType: UInt8 {
        case ipv4 = 0x01
        case domainName = 0x03
        case ipv6 = 0x04
    }
    
    // MARK: - Trojan Request
    struct TrojanRequest {
        let passwordHash: String
        let command: SOCKS5Command
        let addressType: SOCKS5AddressType
        let address: Data
        let port: UInt16
        
        func serialize() -> Data {
            var data = Data()
            
            // Add password hash
            data.append(passwordHash.data(using: .utf8) ?? Data())
            data.append(TrojanProtocol.crlf)
            
            // Add SOCKS5 request
            data.append(command.rawValue)
            data.append(addressType.rawValue)
            data.append(address)
            
            // Add port (big-endian)
            data.append(UInt8(port >> 8))
            data.append(UInt8(port & 0xFF))
            
            data.append(TrojanProtocol.crlf)
            
            return data
        }
    }
    
    // MARK: - Utility Functions
    static func generatePasswordHash(_ password: String) -> String {
        let passwordData = password.data(using: .utf8) ?? Data()
        let hash = SHA256.hash(data: passwordData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    static func createConnectRequest(to host: String, port: UInt16, password: String) -> Data {
        let passwordHash = generatePasswordHash(password)
        
        let request = TrojanRequest(
            passwordHash: passwordHash,
            command: .connect,
            addressType: .domainName,
            address: createDomainNameData(host),
            port: port
        )
        
        return request.serialize()
    }
    
    static func createUDPAssociateRequest(password: String) -> Data {
        let passwordHash = generatePasswordHash(password)
        
        // For UDP associate, we use 0.0.0.0:0
        let request = TrojanRequest(
            passwordHash: passwordHash,
            command: .udpAssociate,
            addressType: .ipv4,
            address: Data([0, 0, 0, 0]), // 0.0.0.0
            port: 0
        )
        
        return request.serialize()
    }
    
    private static func createDomainNameData(_ domain: String) -> Data {
        let domainData = domain.data(using: .utf8) ?? Data()
        var data = Data()
        data.append(UInt8(domainData.count))
        data.append(domainData)
        return data
    }
    
    // MARK: - Packet Processing
    static func wrapUDPPacket(_ packet: Data, destinationAddress: Data, destinationPort: UInt16, addressType: SOCKS5AddressType) -> Data {
        var wrappedPacket = Data()
        
        // Add address type
        wrappedPacket.append(addressType.rawValue)
        
        // Add destination address
        wrappedPacket.append(destinationAddress)
        
        // Add destination port (big-endian)
        wrappedPacket.append(UInt8(destinationPort >> 8))
        wrappedPacket.append(UInt8(destinationPort & 0xFF))
        
        // Add length (big-endian)
        let length = UInt16(packet.count)
        wrappedPacket.append(UInt8(length >> 8))
        wrappedPacket.append(UInt8(length & 0xFF))
        
        // Add CRLF
        wrappedPacket.append(crlf)
        
        // Add actual packet data
        wrappedPacket.append(packet)
        
        return wrappedPacket
    }
    
    static func unwrapUDPPacket(_ data: Data) -> (packet: Data, address: Data, port: UInt16, addressType: SOCKS5AddressType)? {
        guard data.count >= 5 else { return nil }
        
        var offset = 0
        
        // Read address type
        guard let addressType = SOCKS5AddressType(rawValue: data[offset]) else { return nil }
        offset += 1
        
        // Read address
        var address: Data
        switch addressType {
        case .ipv4:
            guard offset + 4 <= data.count else { return nil }
            address = data.subdata(in: offset..<(offset + 4))
            offset += 4
            
        case .ipv6:
            guard offset + 16 <= data.count else { return nil }
            address = data.subdata(in: offset..<(offset + 16))
            offset += 16
            
        case .domainName:
            guard offset + 1 <= data.count else { return nil }
            let domainLength = Int(data[offset])
            offset += 1
            
            guard offset + domainLength <= data.count else { return nil }
            address = data.subdata(in: offset..<(offset + domainLength))
            offset += domainLength
        }
        
        // Read port
        guard offset + 2 <= data.count else { return nil }
        let port = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
        offset += 2
        
        // Read length
        guard offset + 2 <= data.count else { return nil }
        let length = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
        offset += 2
        
        // Skip CRLF
        guard offset + 2 <= data.count else { return nil }
        offset += 2
        
        // Read packet data
        guard offset + Int(length) <= data.count else { return nil }
        let packet = data.subdata(in: offset..<(offset + Int(length)))
        
        return (packet: packet, address: address, port: port, addressType: addressType)
    }
}

// MARK: - Extensions
extension Data {
    func hexString() -> String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

extension String {
    func hexData() -> Data? {
        let len = count / 2
        var data = Data(capacity: len)
        
        for i in 0..<len {
            let j = index(startIndex, offsetBy: i * 2)
            let k = index(j, offsetBy: 2)
            let bytes = self[j..<k]
            if var byte = UInt8(bytes, radix: 16) {
                data.append(&byte, count: 1)
            } else {
                return nil
            }
        }
        
        return data
    }
}