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

import Foundation
import AppKit
import Virtualization

class MacVM: CommonVM {
    
    var dpi = 226
    var auxiliaryStorageURL: URL?
    var hardwareModelURL: URL?
    
    override init(cpus: Int, ram: UInt64, headless: Bool, resolution: String, vmpath: String, netconf: String, sharing: String, initimg: String, initDiskSize: UInt64) {
        
        super.init(cpus: cpus, ram: ram, headless: headless, resolution: resolution, vmpath: vmpath, netconf: netconf, sharing: sharing, initimg: initimg, initDiskSize: initDiskSize)
        
        windowWidth = Int((resolution.split(separator: "x")[0] as NSString).intValue)
        windowHeight = Int((resolution.split(separator: "x")[1] as NSString).intValue)
        dpi = Int((resolution.split(separator: "x")[2] as NSString).intValue)
        auxiliaryStorageURL = URL(fileURLWithPath: vmBundlePath + "AuxiliaryStorage")
        hardwareModelURL = URL(fileURLWithPath: vmBundlePath + "HardwareModel")

    }

    func createGraphicsDeviceConfiguration() -> VZMacGraphicsDeviceConfiguration {

        if dpi >= 224 {
            // assuming retina display
            let scale = window.screen?.backingScaleFactor ?? 1.0
            // scale the window size
            windowWidth = windowWidth * Int(scale)
            windowHeight = windowHeight * Int(scale)
        }

        let graphicsConfiguration = VZMacGraphicsDeviceConfiguration()
        graphicsConfiguration.displays = [
            VZMacGraphicsDisplayConfiguration(widthInPixels: windowWidth, heightInPixels: windowHeight, pixelsPerInch: dpi)
        ]
        return graphicsConfiguration
    }

    private func createMacPlatform(macOSConfiguration: VZMacOSConfigurationRequirements) -> VZMacPlatformConfiguration {
        let macPlatformConfiguration = VZMacPlatformConfiguration()

        guard let auxiliaryStorage = try? VZMacAuxiliaryStorage(creatingStorageAt: auxiliaryStorageURL!,
                                                                    hardwareModel: macOSConfiguration.hardwareModel,
                                                                          options: []) else {
            print("Failed to create auxiliary storage.")
            exit(1)
        }
        macPlatformConfiguration.auxiliaryStorage = auxiliaryStorage
        macPlatformConfiguration.hardwareModel = macOSConfiguration.hardwareModel
        macPlatformConfiguration.machineIdentifier = VZMacMachineIdentifier()

        // Store the hardware model and machine identifier to disk so that we
        // can retrieve them for subsequent boots.
        try! macPlatformConfiguration.hardwareModel.dataRepresentation.write(to: hardwareModelURL!)
        try! macPlatformConfiguration.machineIdentifier.dataRepresentation.write(to: URL(filePath: machineIdentifierPath))

        return macPlatformConfiguration
        
    }
    
    private func getMacPlatform() -> VZMacPlatformConfiguration {

        let macPlatform = VZMacPlatformConfiguration()

        let auxiliaryStorage = VZMacAuxiliaryStorage(contentsOf: auxiliaryStorageURL!)
        macPlatform.auxiliaryStorage = auxiliaryStorage

        if !FileManager.default.fileExists(atPath: vmBundlePath) {
            print("Missing Virtual Machine Bundle at \(vmBundlePath). Run InstallationTool first to create it.")
            exit(1)
        }

        // Retrieve the hardware model; you should save this value to disk during installation.
        guard let hardwareModelData = try? Data(contentsOf: hardwareModelURL!) else {
            print("Failed to retrieve hardware model data.")
            exit(1)
        }

        guard let hardwareModel = VZMacHardwareModel(dataRepresentation: hardwareModelData) else {
            print("Failed to create hardware model.")
            exit(1)
        }

        if !hardwareModel.isSupported {
            print("The hardware model isn't supported on the current host")
            exit(1)
        }
        macPlatform.hardwareModel = hardwareModel

        // Retrieve the machine identifier; you should save this value to disk during installation.
        guard let machineIdentifierData = try? Data(contentsOf: URL(filePath: machineIdentifierPath)) else {
            print("Failed to retrieve machine identifier data.")
            exit(1)
        }

        guard let machineIdentifier = VZMacMachineIdentifier(dataRepresentation: machineIdentifierData) else {
            print("Failed to create machine identifier.")
            exit(1)
        }
        macPlatform.machineIdentifier = machineIdentifier

        return macPlatform
    }

    
    func createVirtualMachine(macOSConfiguration: VZMacOSConfigurationRequirements?) {
        let virtualMachineConfiguration = VZVirtualMachineConfiguration()

        if macOSConfiguration != nil {
            virtualMachineConfiguration.platform = createMacPlatform(macOSConfiguration: macOSConfiguration!)
        } else {
            virtualMachineConfiguration.platform = getMacPlatform()
        }
        virtualMachineConfiguration.bootLoader = VZMacOSBootLoader()
        virtualMachineConfiguration.cpuCount = validateCPUCount(testCPUCount: cpuCount)
        virtualMachineConfiguration.memorySize = validateMemorySize(testMemSize: memSizeMB)
        virtualMachineConfiguration.graphicsDevices = [createGraphicsDeviceConfiguration()]
        virtualMachineConfiguration.storageDevices = [createBlockDeviceConfiguration()]
        virtualMachineConfiguration.networkDevices = createNetworkDeviceConfiguration()
        // trackpad causes scrolling to lockup
        //virtualMachineConfiguration.pointingDevices = [VZMacTrackpadConfiguration()]
        virtualMachineConfiguration.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        virtualMachineConfiguration.keyboards = [VZUSBKeyboardConfiguration()]
        virtualMachineConfiguration.audioDevices = [createInputAudioDeviceConfiguration(), createOutputAudioDeviceConfiguration()]
        if directoryShares != "" {
            virtualMachineConfiguration.directorySharingDevices = createDirectoryShareConfiguration()
        }
        try! virtualMachineConfiguration.validate()
        virtualMachine = VZVirtualMachine(configuration: virtualMachineConfiguration)
        virtualMachine.delegate = self
    }

    func configureAndStartVirtualMachine() {
        self.createVirtualMachine(macOSConfiguration: nil)
        self.startVirtualMachine(captureSystemKeys: true)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        configureAndStartVirtualMachine()
    }
}
