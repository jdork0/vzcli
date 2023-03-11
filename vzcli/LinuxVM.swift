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

class LinuxVM: CommonVM {

    
    override init(cpus: Int, ram: UInt64, headless: Bool, resolution: String, vmpath: String, netconf: String, sharing: String, initimg: String, initDiskSize: UInt64) {

        super.init(cpus: cpus, ram: ram, headless: headless, resolution: resolution, vmpath: vmpath, netconf: netconf, sharing: sharing, initimg: initimg, initDiskSize: initDiskSize)

        vmTypePath = self.vmBundlePath + linuxMarker
        if initImg != "" {
            self.needsInstall = true
            self.initImg = initimg
        }
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
        let virtualMachineConfiguration = VZVirtualMachineConfiguration()

        virtualMachineConfiguration.cpuCount = validateCPUCount(testCPUCount: cpuCount)
        virtualMachineConfiguration.memorySize = validateMemorySize(testMemSize: memSizeMB)

        let platform = VZGenericPlatformConfiguration()
        let bootloader = VZEFIBootLoader()
        let disksArray = NSMutableArray()

        if needsInstall {
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

        virtualMachineConfiguration.platform = platform
        virtualMachineConfiguration.bootLoader = bootloader

        disksArray.add(createBlockDeviceConfiguration())
        guard let disks = disksArray as? [VZStorageDeviceConfiguration] else {
            print("Invalid disksArray.")
            exit(1)
        }
        virtualMachineConfiguration.storageDevices = disks

        virtualMachineConfiguration.networkDevices = createNetworkDeviceConfiguration()
        virtualMachineConfiguration.graphicsDevices = [createGraphicsDeviceConfiguration()]
        virtualMachineConfiguration.audioDevices = [createInputAudioDeviceConfiguration(), createOutputAudioDeviceConfiguration()]

        virtualMachineConfiguration.keyboards = [VZUSBKeyboardConfiguration()]
        virtualMachineConfiguration.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        virtualMachineConfiguration.consoleDevices = [createSpiceAgentConsoleDeviceConfiguration()]

        if directoryShares != "" {
            virtualMachineConfiguration.directorySharingDevices = createDirectoryShareConfiguration()
        }

        try! virtualMachineConfiguration.validate()
        virtualMachine = VZVirtualMachine(configuration: virtualMachineConfiguration)
    }

    func configureAndStartVirtualMachine() {
        self.createVirtualMachine()
        self.startVirtualMachine(captureSystemKeys: false)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if needsInstall {
            createVMBundle()
            createMainDiskImage()
        }
        configureAndStartVirtualMachine()
    }
    
}
