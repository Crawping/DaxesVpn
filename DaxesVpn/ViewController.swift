//
//  ViewController.swift
//  DaxesVpn
//
//  Created by dkdesai on 12/18/17.
//  Copyright © 2017 Daxes Desai. All rights reserved.
//

import UIKit
import NetworkExtension
import SystemConfiguration

class ViewController: UIViewController {
    
    var vpnManager: NETunnelProviderManager = NETunnelProviderManager()
    var connectButton = UIButton()
    
    // Hard code VPN configurations
    let tunnelBundleId = "com.daxes.daxesvpntest.network"
    let serverAddress = ""
    let serverPort = "54345"
    let mtu = "1400"
    let ip = "10.0.0.2"
    let subnet = "255.255.255.255"
    let dns = "8.8.8.8,8.4.4.4"
    
    private let reachability = SCNetworkReachabilityCreateWithName(nil, "localHost")
    private let queue = DispatchQueue.main
    private var currentReachabilityFlags: SCNetworkReachabilityFlags?
    private var isListening = false
    
    private func initVPNTunnelProviderManager() {
        NETunnelProviderManager.loadAllFromPreferences { (savedManagers: [NETunnelProviderManager]?, error: Error?) in
            if let error = error {
                print(error)
            }
            if let savedManagers = savedManagers {
                if savedManagers.count > 0 {
                    self.vpnManager = savedManagers[0]
                }
            }
            
            self.vpnManager.loadFromPreferences(completionHandler: { (error:Error?) in
                if let error = error {
                    print(error)
                }
                
                let providerProtocol = NETunnelProviderProtocol()
                providerProtocol.providerBundleIdentifier = self.tunnelBundleId
                
                providerProtocol.providerConfiguration = ["port": self.serverPort,
                                                          "server": self.serverAddress,
                                                          "ip": self.ip,
                                                          "subnet": self.subnet,
                                                          "mtu": self.mtu,
                                                          "dns": self.dns
                ]
                providerProtocol.serverAddress = self.serverAddress
                self.vpnManager.protocolConfiguration = providerProtocol
                self.vpnManager.localizedDescription = "DaxesVpn"
                self.vpnManager.isEnabled = true
                
                self.vpnManager.saveToPreferences(completionHandler: { (error:Error?) in
                    if let error = error {
                        print(error)
                    } else {
                        print("Save successfully")
                    }
                })
                
                self.VPNStatusDidChange(nil)
                
            })
        }
    }
    
    func start() {
        guard !isListening else { return }
        guard let reachability = reachability else { return }
       
        queue.async {
            self.currentReachabilityFlags = nil
            
            // Reads the new flags
            var flags = SCNetworkReachabilityFlags()
            SCNetworkReachabilityGetFlags(reachability, &flags)
            
            self.checkReachability(flags: flags)
        }
        
        isListening = true
    }
    
    private func checkReachability(flags: SCNetworkReachabilityFlags) {
        if currentReachabilityFlags != flags {
            currentReachabilityFlags = flags
        }
    }
    
    func stop() {
        guard isListening,
            let reachability = reachability
            else { return }
        SCNetworkReachabilitySetCallback(reachability, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(reachability, nil)
        
        isListening = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.view.backgroundColor = UIColor.white
        initVPNTunnelProviderManager()
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.VPNStatusDidChange(_:)), name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
        getStyle()
        start()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func getStyle() {
        self.view.addSubview(connectButton)
        connectButton.translatesAutoresizingMaskIntoConstraints = false
        connectButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        connectButton.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        connectButton.widthAnchor.constraint(equalToConstant: 200).isActive = true
        connectButton.heightAnchor.constraint(equalToConstant: 100).isActive = true
        connectButton.addTarget(self, action: #selector(tryConnect), for: .touchUpInside)
        connectButton.setTitle("Connect", for: .normal)
        connectButton.backgroundColor = UIColor.cyan
        connectButton.layer.cornerRadius = 15
    }
    
    @objc func VPNStatusDidChange(_ notification: Notification?) {
        print("VPN Status changed:")
        let status = self.vpnManager.connection.status
        switch status {
        case .connecting:
            print("Connecting...")
            connectButton.setTitle("Disconnect", for: .normal)
            break
        case .connected:
            print("Connected...")
            connectButton.setTitle("Disconnect", for: .normal)
            break
        case .disconnecting:
            print("Disconnecting...")
            break
        case .disconnected:
            print("Disconnected...")
            connectButton.setTitle("Connect", for: .normal)
            break
        case .invalid:
            print("Invliad")
            break
        case .reasserting:
            print("Reasserting...")
            break
        }
    }
    
    @objc func tryConnect() {
        print("Go!")
        
        self.vpnManager.loadFromPreferences { (error:Error?) in
            if let error = error {
                print(error)
            }
            if (self.connectButton.title(for: .normal) == "Connect") {
                do {
                    try self.vpnManager.connection.startVPNTunnel()
                } catch {
                    print(error)
                }
            } else {
                self.vpnManager.connection.stopVPNTunnel()
            }
        }
    }
    
    
}



