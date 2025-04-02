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

import Foundation
import AppKit
import Virtualization

class LinuxVM: CommonVM {

    
    override init(vmname: String, cpus: Int, ram: UInt64, headless: Bool, resolution: String, vmdir: String, netconf: String, sharing: String, initimg: String, initDiskSize: UInt64) {

        super.init(vmname: vmname, cpus: cpus, ram: ram, headless: headless, resolution: resolution, vmdir: vmdir, netconf: netconf, sharing: sharing, initimg: initimg, initDiskSize: initDiskSize)

        vmTypePath = self.vmDir + linuxMarker
        if initImg != "" {
            self.initializeVM = true
            self.initImg = initimg
        }
    }
    
    // attach the disk image
    override func createBlockDeviceConfiguration() -> VZVirtioBlockDeviceConfiguration {
        guard let mainDiskAttachment = try? VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: mainDiskImagePath), readOnly: false, cachingMode: .cached, synchronizationMode: .fsync) else {
            print("Failed to create main disk attachment.")
            exit(1)
        }
        let mainDisk = VZVirtioBlockDeviceConfiguration(attachment: mainDiskAttachment)
        return mainDisk
    }

    private func createGraphicsDeviceConfiguration() -> VZVirtioGraphicsDeviceConfiguration {
        let graphicsDevice = VZVirtioGraphicsDeviceConfiguration()
        graphicsDevice.scanouts = [
            VZVirtioGraphicsScanoutConfiguration(widthInPixels: windowWidth, heightInPixels: windowHeight)
        ]
        return graphicsDevice
    }

    private func createSpiceAgentConsoleDeviceConfiguration() -> VZVirtioConsoleDeviceConfiguration {
        let consoleDevice = VZVirtioConsoleDeviceConfiguration()
        let spiceAgentPort = VZVirtioConsolePortConfiguration()
        spiceAgentPort.name = VZSpiceAgentPortAttachment.spiceAgentPortName
        spiceAgentPort.attachment = VZSpiceAgentPortAttachment()
        consoleDevice.ports[0] = spiceAgentPort
        return consoleDevice
    }

    func createVirtualMachine() {
        let config = VZVirtualMachineConfiguration()

        config.cpuCount = validateCPUCount(testCPUCount: cpuCount)
        config.memorySize = validateMemorySize(testMemSize: memSizeMB)

        let platform = VZGenericPlatformConfiguration()
        let bootloader = VZEFIBootLoader()
        let disksArray = NSMutableArray()

        if initializeVM {
            // create the machine identifier and efi store
            platform.machineIdentifier = createAndSaveMachineIdentifier()
            bootloader.variableStore = createEFIVariableStore()
            // attach the iso to install OS
            disksArray.add(createUSBMassStorageDeviceConfiguration())
        } else {
            // retrieve the machine identifier and efi store
            platform.machineIdentifier = retrieveMachineIdentifier()
            bootloader.variableStore = retrieveEFIVariableStore()
        }

        config.platform = platform
        config.bootLoader = bootloader
        disksArray.add(createBlockDeviceConfiguration())
        guard let disks = disksArray as? [VZStorageDeviceConfiguration] else {
            print("Invalid disksArray.")
            exit(1)
        }
        config.storageDevices = disks
        config.networkDevices = createNetworkDeviceConfiguration()
        config.graphicsDevices = [createGraphicsDeviceConfiguration()]
        config.audioDevices = [createInputAudioDeviceConfiguration(), createOutputAudioDeviceConfiguration()]
        config.keyboards = [VZUSBKeyboardConfiguration()]
        config.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        config.consoleDevices = [createSpiceAgentConsoleDeviceConfiguration()]
        if directoryShares != "" {
            config.directorySharingDevices = createDirectoryShareConfiguration()
        }
        try! config.validate()
        virtualMachine = VZVirtualMachine(configuration: config)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if initializeVM {
            initEmptyVM()
        }
        let opts = VZVirtualMachineStartOptions()
        self.createVirtualMachine()
        self.startVirtualMachine(captureSystemKeys: false, bootOpts: opts)
    }
    
}
