#if os(iOS)
import NetworkExtension
import Foundation
import Network

class TrojanPacketTunnelProvider: NEPacketTunnelProvider {
    
    private var trojanConnection: TrojanConnection?
    private var pendingStartCompletion: ((Error?) -> Void)?
    private var pendingStopCompletion: (() -> Void)?
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        pendingStartCompletion = completionHandler
        
        guard let protocolConfig = protocolConfiguration as? NETunnelProviderProtocol,
              let config = protocolConfig.providerConfiguration else {
            completionHandler(NSError(domain: "TrojanVPN", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid configuration"]))
            return
        }
        
        guard let serverAddress = config["serverAddress"] as? String,
              let port = config["port"] as? Int,
              let password = config["password"] as? String else {
            completionHandler(NSError(domain: "TrojanVPN", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing required configuration"]))
            return
        }
        
        let sni = config["sni"] as? String
        
        // Setup tunnel network settings
        let tunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: serverAddress)
        
        // Configure IPv4 settings
        let ipv4Settings = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.0.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        tunnelNetworkSettings.ipv4Settings = ipv4Settings
        
        // Configure DNS settings
        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        tunnelNetworkSettings.dnsSettings = dnsSettings
        
        // Set MTU
        tunnelNetworkSettings.mtu = 1500
        
        setTunnelNetworkSettings(tunnelNetworkSettings) { [weak self] error in
            if let error = error {
                completionHandler(error)
                return
            }
            
            // Start Trojan connection
            self?.startTrojanConnection(
                serverAddress: serverAddress,
                port: port,
                password: password,
                sni: sni,
                config: config
            )
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        pendingStopCompletion = completionHandler
        
        trojanConnection?.disconnect()
        trojanConnection = nil
        
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Handle messages from the main app if needed
        completionHandler?(nil)
    }
    
    private func startTrojanConnection(serverAddress: String, port: Int, password: String, sni: String?, config: [String: Any]) {
        trojanConnection = TrojanConnection(
            serverAddress: serverAddress,
            port: port,
            password: password,
            sni: sni,
            packetFlow: packetFlow,
            config: config
        )
        
        trojanConnection?.delegate = self
        trojanConnection?.connect { [weak self] (error: Error?) in
            DispatchQueue.main.async {
                if let error = error {
                    self?.pendingStartCompletion?(error)
                } else {
                    self?.pendingStartCompletion?(nil)
                    self?.startPacketForwarding()
                }
                self?.pendingStartCompletion = nil
            }
        }
    }
    
    private func startPacketForwarding() {
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self else { return }
            
            // Forward packets through Trojan connection
            for (index, packet) in packets.enumerated() {
                let protocolFamily = protocols[index]
                self.trojanConnection?.sendPacket(packet, protocolFamily: protocolFamily)
            }
            
            // Continue reading packets
            self.startPacketForwarding()
        }
    }
}

extension TrojanPacketTunnelProvider: TrojanConnectionDelegate {
    func trojanConnection(_ connection: TrojanConnection, didReceivePacket packet: Data, protocolFamily: NSNumber) {
        packetFlow.writePackets([packet], withProtocols: [protocolFamily])
    }
    
    func trojanConnection(_ connection: TrojanConnection, didDisconnectWithError error: Error?) {
        if let error = error {
            cancelTunnelWithError(error)
        }
    }
}
#endif