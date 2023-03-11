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
import Virtualization
import AppKit
import ArgumentParser

struct vzcli: ParsableCommand {
    @Option() var cpus = 4
    @Option() var mem = 8192
    @Option() var resolution = "1280x800x226"
    @Option() var net = "user"
    @Option() var sharing = ""
    @Flag() var headless = false
    @Option() var initLinux = ""
    @Flag() var initMacos = false
    @Option() var initMacosIPSW = ""
    @Option() var initDiskSize = UInt64(64)
    @Flag() var generateMac = false
    @Argument() var vmPath: String

    func run() {

        if generateMac {
            let randomMac = VZMACAddress.randomLocallyAdministered()
            print("Randon MAC Address: " + randomMac.description)
            return
        }
        
        let app = NSApplication.shared
                
        if !headless {
            app.setActivationPolicy(.regular)
        }
        // launch a linux vm
        if initLinux != "" || FileManager.default.fileExists(atPath: vmPath + "/" + linuxMarker) {
            let delegate = LinuxVM(cpus: cpus, ram: UInt64(mem), headless: headless, resolution: resolution, vmpath: vmPath, netconf: net, sharing: sharing, initimg: initLinux, initDiskSize: initDiskSize)
            app.delegate = delegate
            app.run()
            return
        }
        // create a new macOS vm
        if initMacos {
            let delegate = CreateMacVM(cpus: cpus, ram: UInt64(mem), headless: headless, resolution: resolution, vmpath: vmPath, netconf: net, sharing: sharing, initimg: initMacosIPSW, initDiskSize: initDiskSize)
            app.delegate = delegate
            app.run()
            return
        }
        // launch an existing macOS vm
        if FileManager.default.fileExists(atPath: vmPath + "/" + macOSMarker) {
            let delegate = MacVM(cpus: cpus, ram: UInt64(mem), headless: headless, resolution: resolution, vmpath: vmPath, netconf: net, sharing: sharing, initimg: initMacosIPSW, initDiskSize: initDiskSize)
            app.delegate = delegate
            app.run()
            return
        }
        print("No vm found: " + vmPath)
    }
}

vzcli.main()
