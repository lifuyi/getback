import Foundation
import Network

struct PacketParser {
    
    // MARK: - IP Packet Parsing
    
    static func parseIPPacket(_ data: Data) -> IPPacket? {
        guard data.count >= 20 else { return nil } // Minimum IPv4 header size
        
        let versionAndHeaderLength = data[0]
        let version = (versionAndHeaderLength >> 4) & 0x0F
        let headerLength = Int(versionAndHeaderLength & 0x0F) * 4
        
        guard version == 4 || version == 6 else { return nil }
        
        if version == 4 {
            return parseIPv4Packet(data, headerLength: headerLength)
        } else {
            return parseIPv6Packet(data)
        }
    }
    
    private static func parseIPv4Packet(_ data: Data, headerLength: Int) -> IPPacket? {
        guard data.count >= headerLength else { return nil }
        
        let totalLength = Int(data[2]) << 8 | Int(data[3])
        guard data.count >= totalLength else { return nil }
        
        let protocolType = data[9]
        let sourceIP = data.subdata(in: 12..<16)
        let destinationIP = data.subdata(in: 16..<20)
        
        let payload = data.subdata(in: headerLength..<totalLength)
        
        return IPPacket(
            version: 4,
            protocolType: protocolType,
            sourceAddress: sourceIP,
            destinationAddress: destinationIP,
            payload: payload,
            totalLength: totalLength
        )
    }
    
    private static func parseIPv6Packet(_ data: Data) -> IPPacket? {
        guard data.count >= 40 else { return nil } // IPv6 header size
        
        let payloadLength = Int(data[4]) << 8 | Int(data[5])
        let nextHeader = data[6]
        let sourceIP = data.subdata(in: 8..<24)
        let destinationIP = data.subdata(in: 24..<40)
        
        let totalLength = 40 + payloadLength
        guard data.count >= totalLength else { return nil }
        
        let payload = data.subdata(in: 40..<totalLength)
        
        return IPPacket(
            version: 6,
            protocolType: nextHeader,
            sourceAddress: sourceIP,
            destinationAddress: destinationIP,
            payload: payload,
            totalLength: totalLength
        )
    }
    
    // MARK: - TCP/UDP Parsing
    
    static func parseTCPHeader(_ data: Data) -> TCPHeader? {
        guard data.count >= 20 else { return nil }
        
        let sourcePort = UInt16(data[0]) << 8 | UInt16(data[1])
        let destinationPort = UInt16(data[2]) << 8 | UInt16(data[3])
        let sequenceNumber = UInt32(data[4]) << 24 | UInt32(data[5]) << 16 | UInt32(data[6]) << 8 | UInt32(data[7])
        let acknowledgmentNumber = UInt32(data[8]) << 24 | UInt32(data[9]) << 16 | UInt32(data[10]) << 8 | UInt32(data[11])
        
        let dataOffsetAndFlags = UInt16(data[12]) << 8 | UInt16(data[13])
        let dataOffset = Int((dataOffsetAndFlags >> 12) & 0x0F) * 4
        let flags = dataOffsetAndFlags & 0x01FF
        
        let windowSize = UInt16(data[14]) << 8 | UInt16(data[15])
        let checksum = UInt16(data[16]) << 8 | UInt16(data[17])
        let urgentPointer = UInt16(data[18]) << 8 | UInt16(data[19])
        
        return TCPHeader(
            sourcePort: sourcePort,
            destinationPort: destinationPort,
            sequenceNumber: sequenceNumber,
            acknowledgmentNumber: acknowledgmentNumber,
            dataOffset: dataOffset,
            flags: flags,
            windowSize: windowSize,
            checksum: checksum,
            urgentPointer: urgentPointer
        )
    }
    
    static func parseUDPHeader(_ data: Data) -> UDPHeader? {
        guard data.count >= 8 else { return nil }
        
        let sourcePort = UInt16(data[0]) << 8 | UInt16(data[1])
        let destinationPort = UInt16(data[2]) << 8 | UInt16(data[3])
        let length = UInt16(data[4]) << 8 | UInt16(data[5])
        let checksum = UInt16(data[6]) << 8 | UInt16(data[7])
        
        return UDPHeader(
            sourcePort: sourcePort,
            destinationPort: destinationPort,
            length: length,
            checksum: checksum
        )
    }
}

// MARK: - Data Structures

struct IPPacket {
    let version: UInt8
    let protocolType: UInt8
    let sourceAddress: Data
    let destinationAddress: Data
    let payload: Data
    let totalLength: Int
    
    var isIPv4: Bool { version == 4 }
    var isIPv6: Bool { version == 6 }
    var isTCP: Bool { protocolType == 6 }
    var isUDP: Bool { protocolType == 17 }
    var isICMP: Bool { protocolType == 1 || protocolType == 58 } // ICMPv4 or ICMPv6
}

struct TCPHeader {
    let sourcePort: UInt16
    let destinationPort: UInt16
    let sequenceNumber: UInt32
    let acknowledgmentNumber: UInt32
    let dataOffset: Int
    let flags: UInt16
    let windowSize: UInt16
    let checksum: UInt16
    let urgentPointer: UInt16
    
    var isSYN: Bool { (flags & 0x0002) != 0 }
    var isACK: Bool { (flags & 0x0010) != 0 }
    var isFIN: Bool { (flags & 0x0001) != 0 }
    var isRST: Bool { (flags & 0x0004) != 0 }
    var isPSH: Bool { (flags & 0x0008) != 0 }
    var isURG: Bool { (flags & 0x0020) != 0 }
}

struct UDPHeader {
    let sourcePort: UInt16
    let destinationPort: UInt16
    let length: UInt16
    let checksum: UInt16
}

// MARK: - Extensions

extension Data {
    func toIPAddress() -> String? {
        if count == 4 {
            // IPv4
            return "\(self[0]).\(self[1]).\(self[2]).\(self[3])"
        } else if count == 16 {
            // IPv6
            var components: [String] = []
            for i in stride(from: 0, to: 16, by: 2) {
                let value = UInt16(self[i]) << 8 | UInt16(self[i + 1])
                components.append(String(format: "%x", value))
            }
            return components.joined(separator: ":")
        }
        return nil
    }
}