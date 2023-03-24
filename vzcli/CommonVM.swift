//
// Copyright © 2023 Jason Kelly. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// See LICENSE file
//


import Virtualization
import System
import Darwin
import Foundation
import AppKit
import Usernet

var linuxMarker = ".linux"
var macOSMarker = ".macos"

class CommonVM: NSObject, NSApplicationDelegate, VZVirtualMachineDelegate {
    
    var vmDir: String
    var vmName: String
    var vmTypePath = ""
    var initImg = ""
    var mainDiskImagePath: String
    var mainDiskSize = UInt64(64)
    var cpuCount: Int
    var memSizeMB: UInt64
    var efiVariableStorePath: String
    var machineIdentifierPath: String
    var directoryShares: String
    var netConf: String
    var initializeVM = false
    var virtualMachine: VZVirtualMachine!
    var enableUI: Bool
    var window: NSWindow
    var windowWidth: Int
    var windowHeight: Int

    
    init(cpus: Int, ram: UInt64, headless: Bool, resolution: String, vmdir: String, netconf: String, sharing: String, initimg: String, initDiskSize: UInt64) {

        vmDir = vmdir + "/"
        vmName = CommonVM.parseVMName(vmpath: vmdir)
        mainDiskImagePath = vmDir + "Disk.img"
        cpuCount = cpus
        memSizeMB = ram
        efiVariableStorePath = vmDir + "NVRAM"
        machineIdentifierPath = vmDir + "MachineIdentifier"
        initImg = initimg
        netConf = netconf
        directoryShares = sharing
        enableUI = !headless
        windowWidth = Int((resolution.split(separator: "x")[0] as NSString).intValue)
        windowHeight = Int((resolution.split(separator: "x")[1] as NSString).intValue)

        window = NSWindow(contentRect: NSMakeRect(200, 200, CGFloat(windowWidth), CGFloat(windowHeight)),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)

        super.init()
    }

    func initEmptyVM() {
        // fail out if the directory already exists
        var isDir:ObjCBool = true
        if FileManager.default.fileExists(atPath: vmDir, isDirectory: &isDir) {
            print("Directory already exists: " + vmDir)
            exit(1)
        }
        do {
            // create the directory
            try FileManager.default.createDirectory(atPath: vmDir, withIntermediateDirectories: false)
            // create the type marker
            FileManager.default.createFile(atPath: vmTypePath, contents: nil, attributes: nil)
            // initialize an empty disk image
            FileManager.default.createFile(atPath: mainDiskImagePath, contents: nil, attributes: nil)
            let mainDiskFileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: mainDiskImagePath))
            try mainDiskFileHandle.truncate(atOffset: mainDiskSize * 1024 * 1024 * 1024)
        } catch {
            print("Failed to initialize empty vm: " + vmDir)
            exit(1)
        }
    }
    
    // attach the disk image
    func createBlockDeviceConfiguration() -> VZVirtioBlockDeviceConfiguration {
        guard let mainDiskAttachment = try? VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: mainDiskImagePath), readOnly: false) else {
            print("Failed to create main disk attachment.")
            exit(1)
        }
        let mainDisk = VZVirtioBlockDeviceConfiguration(attachment: mainDiskAttachment)
        return mainDisk
    }

    // validate cpu is within bounds
    func validateCPUCount(testCPUCount: Int) -> Int {
        var virtualCPUCount = testCPUCount
        virtualCPUCount = max(virtualCPUCount, VZVirtualMachineConfiguration.minimumAllowedCPUCount)
        virtualCPUCount = min(virtualCPUCount, VZVirtualMachineConfiguration.maximumAllowedCPUCount)
        return virtualCPUCount
    }

    // validate memory setting and return in bytes
    func validateMemorySize(testMemSize: UInt64) -> UInt64 {
        var memorySize = (testMemSize * 1024 * 1024) as UInt64
        memorySize = max(memorySize, VZVirtualMachineConfiguration.minimumAllowedMemorySize)
        memorySize = min(memorySize, VZVirtualMachineConfiguration.maximumAllowedMemorySize)
        return memorySize
    }

    // create the machine identifier
    func createAndSaveMachineIdentifier() -> VZGenericMachineIdentifier {
        let machineIdentifier = VZGenericMachineIdentifier()
        // Store the machine identifier to disk so it can be retrieved on next boot
        try! machineIdentifier.dataRepresentation.write(to: URL(fileURLWithPath: machineIdentifierPath))
        return machineIdentifier
    }

    // retrieve the machine identifier
    func retrieveMachineIdentifier() -> VZGenericMachineIdentifier {
        // Retrieve the machine identifier.
        guard let machineIdentifierData = try? Data(contentsOf: URL(fileURLWithPath: machineIdentifierPath)) else {
            print("Failed to retrieve the machine identifier data.")
            exit(1)
        }
        guard let machineIdentifier = VZGenericMachineIdentifier(dataRepresentation: machineIdentifierData) else {
            print("Failed to create the machine identifier.")
            exit(1)
        }
        return machineIdentifier
    }

    // create efi store
    func createEFIVariableStore() -> VZEFIVariableStore {
        guard let efiVariableStore = try? VZEFIVariableStore(creatingVariableStoreAt: URL(fileURLWithPath: efiVariableStorePath)) else {
            print("Failed to create the EFI variable store.")
            exit(1)
        }
        return efiVariableStore
    }

    // retrieve efi store
    func retrieveEFIVariableStore() -> VZEFIVariableStore {
        if !FileManager.default.fileExists(atPath: efiVariableStorePath) {
            print("EFI variable store does not exist.")
            exit(1)
        }
        return VZEFIVariableStore(url: URL(fileURLWithPath: efiVariableStorePath))
    }

    // attach the installer iso to install linux vms
    func createUSBMassStorageDeviceConfiguration() -> VZUSBMassStorageDeviceConfiguration {
        guard let installerISOPath = URL(string: "file://" + initImg) else {
            print("Invalid initialization image.")
            exit(1)
        }
        guard let intallerDiskAttachment = try? VZDiskImageStorageDeviceAttachment(url: installerISOPath, readOnly: true) else {
            print("Failed to create installer's disk attachment.")
            exit(1)
        }
        return VZUSBMassStorageDeviceConfiguration(attachment: intallerDiskAttachment)
    }

    // creates all the directory shares
    func createDirectoryShareConfiguration() -> [VZVirtioFileSystemDeviceConfiguration] {
        
        var allShares: [VZVirtioFileSystemDeviceConfiguration] = []

        do {
            // share string is formatted as tag1:directory:[rw|ro],tag2:directory2:[rw|ro], etc...
            // a special value of rosetta enables rosetta mount
            for share in directoryShares.split(separator: "+") {
                if share == "rosetta" {
                    let rosettaDirectoryShare = try VZLinuxRosettaDirectoryShare()
                    let fileSystemDevice = VZVirtioFileSystemDeviceConfiguration(tag: "rosetta")
                    fileSystemDevice.share = rosettaDirectoryShare
                    allShares.append(fileSystemDevice)
                } else {
                    let tag = String(share.split(separator: ":")[0])
                    let directory = String(share.split(separator: ":")[1])
                    let flag = String(share.split(separator: ":")[2])
                    var mntReadOnly = true
                    if flag == "rw" {
                        mntReadOnly = false
                    }
                    let sharedDirectory = VZSharedDirectory(url: URL(filePath: directory), readOnly: mntReadOnly)
                    let singleDirectoryShare = VZSingleDirectoryShare(directory: sharedDirectory)
                    let sharingConfig = VZVirtioFileSystemDeviceConfiguration(tag: tag)
                    sharingConfig.share = singleDirectoryShare
                    allShares.append(sharingConfig)
                }
            }
            return allShares
        } catch {
            print("Could not enable sharing.")
            exit(1)
        }
    }
    
    // create the network devices
    // TODO: refactor with different methods per type
    func createNetworkDeviceConfiguration() -> [VZVirtioNetworkDeviceConfiguration] {

        // array of network devices to add
        var netDevices: [VZVirtioNetworkDeviceConfiguration] = []

        // netConf formatted as type:opts,type:opts,...
        for devConf in netConf.split(separator: "+") {
            
            // the current device to configure
            let networkDevice = VZVirtioNetworkDeviceConfiguration()

            // break up the netConf string into type:opts
            var netType = ""
            var netOpts = ""
            if devConf.contains(":") {
                // has options, split them out
                let index = devConf.firstIndex(of: ":")!
                netType = String(devConf[..<index])
                let nextIndex = devConf.index(index, offsetBy: 1)
                netOpts = String(devConf[nextIndex...])
            } else {
                // no options, just a type
                netType = String(devConf)
            }
            
            // handle the different types (user, nat, bridged)
            switch netType {
            case "user":
                // socket based user networking provided by usernet (go frontend to gvisor)
                // netOpts will be list of port forwards
                
                // create a socketpair
                let socket_pair = Array<Int32>(unsafeUninitializedCapacity: 2) { buffer, initializedCount in
                    guard Darwin.socketpair(AF_UNIX, SOCK_DGRAM, 0, buffer.baseAddress) == 0 else {
                        assertionFailure(String(cString: Darwin.strerror(errno)!))
                        initializedCount = 0
                        return
                    }
                    initializedCount = 2
                }

                // set the socket buffers
                var sendSize = Int32(4*1024*1024)
                var recvSize = Int32(1*1024*1024)
                let socklen = socklen_t(sendSize)
                // set the "server side" (socket passed to usernet)
                Darwin.setsockopt(socket_pair[0], SOL_SOCKET, SO_SNDBUF, &sendSize, socklen)
                Darwin.setsockopt(socket_pair[0], SOL_SOCKET, SO_RCVBUF, &recvSize, socklen)
                // set "client side" (the vm)
                Darwin.setsockopt(socket_pair[1], SOL_SOCKET, SO_SNDBUF, &recvSize, socklen)
                Darwin.setsockopt(socket_pair[1], SOL_SOCKET, SO_RCVBUF, &sendSize, socklen)

                // start user network, passing in first socket of pair and the port forwarding options
                DispatchQueue.main.async {
                    UsernetStartUserNet(socket_pair[0],netOpts)
                }

                // connect second socket as vm device
                let socketDev = VZFileHandleNetworkDeviceAttachment(fileHandle: FileHandle(fileDescriptor: socket_pair[1]))
                // hard code the mac address on this connection
                // should probably block two "user" type interfaces on same VM
                let vzMac = VZMACAddress(string: "5a:ca:b5:c7:1b:e7")!
                networkDevice.macAddress = vzMac
                networkDevice.attachment = socketDev

            case "nat":
                // vz nat networking, netOpts is a macaddress
                if netOpts == "" {
                    print("Must specify MAC Address for nat.")
                    exit(1)
                }
                let natDevice = VZNATNetworkDeviceAttachment()
                let vzMac = VZMACAddress(string: netOpts)
                if vzMac != nil {
                    // set it on device
                    networkDevice.macAddress = vzMac!
                } else {
                    print("Invalid mac address: " + netOpts)
                    exit(1)
                }
                networkDevice.attachment = natDevice

            case "bridged":
                // netOpts for bridged should be interface:mac (en0:aa:bb:cc:dd:ee:ff)
                if !netOpts.contains(":") {
                    print("Invalid bridged config: " + netOpts)
                    exit(1)
                }
                
                //  split out the interface:mac
                let index = netOpts.firstIndex(of: ":")!
                let phyItfName = String(netOpts[..<index])
                let nextIndex = netOpts.index(index, offsetBy: 1)
                let macAddress = String(netOpts[nextIndex...])

                // check that the interface exists
                var found = false
                var bridgeItf: VZBridgedNetworkInterface?
                for interface in VZBridgedNetworkInterface.networkInterfaces {
                    if interface.identifier == phyItfName {
                        bridgeItf = interface
                        found = true
                        break
                    }
                }
                if found {
                    // device was found, attach it
                    let attachment = VZBridgedNetworkDeviceAttachment(interface: bridgeItf!)
                    networkDevice.attachment = attachment
                    // validate the mac address is ok
                    let vzMac = VZMACAddress(string: macAddress)
                    if vzMac != nil {
                        // set it on device
                        networkDevice.macAddress = vzMac!
                    } else {
                        print("Invalid mac address: " + macAddress)
                        exit(1)
                    }
                } else {
                    print("Bridge interface not found: " + phyItfName)
                    exit(1)
                }

            default:
                // not a valid type (user, nat, bridged)
                print("Invalid network type: " + devConf)
                exit(1)
            }
            // add the device to the list
            netDevices.append(networkDevice)
        }
        // return the list of network devices
        return netDevices
    }

//        // old code to connect to external socket before usernet was built in
//        // delete the local socket if it still exists
//        let fileManager = FileManager.default
//        if fileManager.fileExists(atPath: vzSocketPath) {
//            try! fileManager.removeItem(atPath: vzSocketPath)
//        }
//
//        let vzSocketFD = socket(AF_UNIX, SOCK_DGRAM, 0)
//
//        var localAddr = sockaddr_un()
//        localAddr.sun_family = UInt8(AF_UNIX)
//        localAddr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
//        strlcpy(&localAddr.sun_path.0, vzSocketPath, MemoryLayout.size(ofValue: localAddr.sun_path))
//        let localSocklen = socklen_t(localAddr.sun_len)
//
//        var result = withUnsafePointer(to: &localAddr) {
//            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
//                Darwin.bind(vzSocketFD, $0, localSocklen)
//            }
//        }
//        if result == -1 {
//            print("Bind failed.")
//            exit(1)
//        }
//
//        var remoteAddr = sockaddr_un()
//        remoteAddr.sun_family = UInt8(AF_UNIX)
//        remoteAddr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
//        strlcpy(&remoteAddr.sun_path.0, gvzSocketPath, MemoryLayout.size(ofValue: remoteAddr.sun_path))
//        let socklen = socklen_t(remoteAddr.sun_len)
//
//        result = withUnsafePointer(to: &remoteAddr) {
//            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
//                connect(vzSocketFD, $0, socklen);
//            }
//        }
//
//        if result == -1 {
//            print("Socket connect failed.")
//            exit(1)
//        }
//
//        // say hello to gvisor so it can connect back to us
//        let textToSend = "yo"
//        textToSend.withCString { cstr -> Void in
//            send(vzSocketFD, cstr, Int(strlen(cstr)), 0)
//        }
//
//        let socketDev = VZFileHandleNetworkDeviceAttachment(fileHandle: FileHandle(fileDescriptor: vzSocketFD))
//
//        let networkDevice = VZVirtioNetworkDeviceConfiguration()
//        networkDevice.attachment = socketDev
//        return networkDevice

    // create the input audio device
    func createInputAudioDeviceConfiguration() -> VZVirtioSoundDeviceConfiguration {
        let inputAudioDevice = VZVirtioSoundDeviceConfiguration()
        let inputStream = VZVirtioSoundDeviceInputStreamConfiguration()
        inputStream.source = VZHostAudioInputStreamSource()
        inputAudioDevice.streams = [inputStream]
        return inputAudioDevice
    }

    // create the output audio device
    func createOutputAudioDeviceConfiguration() -> VZVirtioSoundDeviceConfiguration {
        let outputAudioDevice = VZVirtioSoundDeviceConfiguration()
        let outputStream = VZVirtioSoundDeviceOutputStreamConfiguration()
        outputStream.sink = VZHostAudioOutputStreamSink()
        outputAudioDevice.streams = [outputStream]
        return outputAudioDevice
    }

    // starts the virtual machine
    func startVirtualMachine(captureSystemKeys: Bool, bootOpts: VZVirtualMachineStartOptions)
    {
        DispatchQueue.main.async {
            // display the window and connect to vm if not headless
            if self.enableUI {
                // open a window with the GUI
                self.window.orderFrontRegardless()
                // get the view of virtualmachine
                let virtualMachineView = VZVirtualMachineView()
                virtualMachineView.virtualMachine = self.virtualMachine
                // capture system keys is true for macOS, false for Linux
                virtualMachineView.capturesSystemKeys = captureSystemKeys
                // set the window view to the vm view
                self.window.contentView = virtualMachineView
                // set it so vm handles input without having to click window
                self.window.makeFirstResponder(virtualMachineView)
                self.window.makeKeyAndOrderFront(nil)
                // set the window and badge to the vm name
                NSApp.dockTile.badgeLabel = self.vmName
                self.window.title = self.vmName
                // bring the window to front
                NSApp.activate(ignoringOtherApps: true)
            }
            // handle delegate calls
            self.virtualMachine.delegate = self
            // start the vm
            self.virtualMachine.start(options: bootOpts, completionHandler: { (error) in
                if error != nil {
                    print("VM failed to start: " + error!.localizedDescription)
                    exit(1)
                } else {
                    print("VM started.")
                }
            })
        }

    }
    
    // exit if window closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // virtual machine stopped with error
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        print("VM stopped with error: " + error.localizedDescription)
        exit(1)
    }

    // virtual machine stopped
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        print("VM stopped.")
        exit(0)
    }

    // net error
    func virtualMachine(_ virtualMachine: VZVirtualMachine, networkDevice: VZNetworkDevice, attachmentWasDisconnectedWithError error: Error) {
        print("Network attachment error: " + error.localizedDescription)
    }
    
    static func parseVMName(vmpath: String) -> String {
        let pathComponents = vmpath.split{ $0 == "/" }.map(String.init)
        return pathComponents.last!
    }
    
}
