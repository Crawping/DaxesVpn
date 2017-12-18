//
//  PacketTunnelProvider.swift
//  DaxesVpnNetwork
//
//  Created by dkdesai on 12/18/17.
//  Copyright © 2017 Daxes Desai. All rights reserved.
//

import Foundation
import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {
    var session: NWUDPSession? = nil
    var conf = [String: AnyObject]()

    func tunToUDP() {
        self.packetFlow.readPackets { (packets: [Data], protocols: [NSNumber]) in
            for packet in packets {
        
                self.session?.writeDatagram(packet, completionHandler: { (error: Error?) in
                    if let error = error {
                        print(error)
                        self.setupUDPSession()
                        return
                    }
                })
            }
            self.tunToUDP()
        }
    }
    
    func udpToTun() {

        session?.setReadHandler({ (_packets: [Data]?, error: Error?) -> Void in
            if let packets = _packets {
                self.packetFlow.writePackets(packets, withProtocols: [NSNumber](repeating: AF_INET as NSNumber, count: packets.count))
            }
        }, maxDatagrams: NSIntegerMax)
    }
    
    func setupPacketTunnelNetworkSettings() {
        let tunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: self.protocolConfiguration.serverAddress!)
        tunnelNetworkSettings.ipv4Settings = NEIPv4Settings(addresses: [conf["ip"] as! String], subnetMasks: [conf["subnet"] as! String])
        
        tunnelNetworkSettings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]
        
        tunnelNetworkSettings.mtu = Int(conf["mtu"] as! String) as NSNumber?
        
        let dnsSettings = NEDNSSettings(servers: (conf["dns"] as! String).components(separatedBy: ","))
        // This overrides system DNS settings
        dnsSettings.matchDomains = [""]
        tunnelNetworkSettings.dnsSettings = dnsSettings
        
        self.setTunnelNetworkSettings(tunnelNetworkSettings) { (error: Error?) -> Void in
            self.udpToTun()
        }
    }
    
    func setupUDPSession() {
        if self.session != nil {
            self.reasserting = true
            self.session = nil
        }
        let serverAddress = self.conf["server"] as! String
        let serverPort = self.conf["port"] as! String
        self.reasserting = false
        self.setTunnelNetworkSettings(nil) { (error: Error?) -> Void in
            if let error = error {
                print(error)
            }
            self.session = self.createUDPSession(to: NWHostEndpoint(hostname: serverAddress, port: serverPort), from: nil)
            self.setupPacketTunnelNetworkSettings()
        }
    }
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        conf = (self.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration! as [String : AnyObject]
        self.setupUDPSession()
        self.tunToUDP()
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        session?.cancel()
        super.stopTunnel(with: reason, completionHandler: completionHandler)
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
    override func wake() {
    }
}
