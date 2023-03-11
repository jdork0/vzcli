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

        let graphicsConfiguration = VZMacGraphicsDeviceConfiguration()

        if dpi >= 200 {
            // assuming high density display
            let scale = window.screen?.backingScaleFactor ?? 1.0
            // scale the display config up so it's higher res in the window size user specified
            // if user said 1200x800, window will be sized 1200x800, but display will be 2400x1600 (higher density)
            windowWidth = windowWidth * Int(scale)
            windowHeight = windowHeight * Int(scale)
        }

        graphicsConfiguration.displays = [
            VZMacGraphicsDisplayConfiguration(widthInPixels: windowWidth, heightInPixels: windowHeight, pixelsPerInch: dpi)
        ]

        return graphicsConfiguration
    }

    private func createMacPlatform(macOSConfiguration: VZMacOSConfigurationRequirements) -> VZMacPlatformConfiguration {
        let platform = VZMacPlatformConfiguration()

        // create the aux storage
        guard let auxiliaryStorage = try? VZMacAuxiliaryStorage(creatingStorageAt: auxiliaryStorageURL!,
                                                                    hardwareModel: macOSConfiguration.hardwareModel,
                                                                          options: []) else {
            print("Failed to create auxiliary storage.")
            exit(1)
        }
        platform.auxiliaryStorage = auxiliaryStorage
        platform.hardwareModel = macOSConfiguration.hardwareModel
        platform.machineIdentifier = VZMacMachineIdentifier()

        // write to disk so they can be loaded when running the vm
        try! platform.hardwareModel.dataRepresentation.write(to: hardwareModelURL!)
        try! platform.machineIdentifier.dataRepresentation.write(to: URL(filePath: machineIdentifierPath))

        return platform
    }
    
    private func getMacPlatform() -> VZMacPlatformConfiguration {

        let platform = VZMacPlatformConfiguration()

        let auxiliaryStorage = VZMacAuxiliaryStorage(contentsOf: auxiliaryStorageURL!)
        platform.auxiliaryStorage = auxiliaryStorage

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
        platform.hardwareModel = hardwareModel

        guard let machineIdentifierData = try? Data(contentsOf: URL(filePath: machineIdentifierPath)) else {
            print("Failed to retrieve machine identifier data.")
            exit(1)
        }

        guard let machineIdentifier = VZMacMachineIdentifier(dataRepresentation: machineIdentifierData) else {
            print("Failed to create machine identifier.")
            exit(1)
        }
        platform.machineIdentifier = machineIdentifier

        return platform
    }

    
    func createVirtualMachine(macOSConfiguration: VZMacOSConfigurationRequirements?) {
        let config = VZVirtualMachineConfiguration()

        if macOSConfiguration != nil {
            config.platform = createMacPlatform(macOSConfiguration: macOSConfiguration!)
        } else {
            config.platform = getMacPlatform()
        }
        config.bootLoader = VZMacOSBootLoader()
        config.cpuCount = validateCPUCount(testCPUCount: cpuCount)
        config.memorySize = validateMemorySize(testMemSize: memSizeMB)
        config.graphicsDevices = [createGraphicsDeviceConfiguration()]
        config.storageDevices = [createBlockDeviceConfiguration()]
        config.networkDevices = createNetworkDeviceConfiguration()
        // trackpad causes scrolling to lockup
        //config.pointingDevices = [VZMacTrackpadConfiguration()]
        config.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        config.keyboards = [VZUSBKeyboardConfiguration()]
        config.audioDevices = [createInputAudioDeviceConfiguration(), createOutputAudioDeviceConfiguration()]
        if directoryShares != "" {
            config.directorySharingDevices = createDirectoryShareConfiguration()
        }
        try! config.validate()
        virtualMachine = VZVirtualMachine(configuration: config)
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
