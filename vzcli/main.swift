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
import Virtualization
import AppKit
import ArgumentParser

struct vzcli: ParsableCommand {
    @Option(help: "Number of cpus.") var cpus = 4
    @Option(help: "RAM in MB.") var mem = 8192
    @Option(help: "Display resolution [width x height x dpi] (dpi macOS only)") var resolution = "1280x800x224"
    @Option(help: "List of type:options\n  user:[host:<hostport>:<guestport>,<hostport2>:<guestport2>,...]\n  bridged:interface:mac\n  nat:mac\nexample: --net user:2222,22+bridged:en0:2e:1c:46:7a:f8:68\n") var net = "user"
    @Option(help: "List of directories exposed to guest by virtiofs\n  rosetta (linux rosetta support)\n  tag:directory:ro|rw\nexample: --virtiofs rosetta+home:/Users/test/test:rw\n") var virtiofs = ""
    @Flag(help: "No GUI") var headless = false
    @Option(help: "Path to Linux install iso") var initLinux = ""
    @Flag(help: "Create a new macOS VM") var initMacos = false
    @Option(help: "Use specified restore.ipsw instead of downloading latest.") var initMacosIPSW = ""
    @Option(help: "Disk size in GB.") var initDiskSize = UInt64(64)
    @Flag(help: "Generate a MAC Address to use with bridged networking.") var generateMac = false
    @Argument(help: "Path to VM directory") var vmDir: String

    func run() {

        if generateMac {
            let randomMac = VZMACAddress.randomLocallyAdministered()
            print("Randon MAC Address: " + randomMac.description)
            return
        }
        
        let app = NSApplication.shared
                
        if headless || initMacos || initMacosIPSW != "" {
            // no window / dock icon
            app.setActivationPolicy(.prohibited)
        } else {
            app.setActivationPolicy(.regular)
        }

        // launch a linux vm
        if initLinux != "" || FileManager.default.fileExists(atPath: vmDir + "/" + linuxMarker) {
            let delegate = LinuxVM(cpus: cpus, ram: UInt64(mem), headless: headless, resolution: resolution, vmdir: vmDir, netconf: net, sharing: virtiofs, initimg: initLinux, initDiskSize: initDiskSize)
            app.delegate = delegate
            app.run()
            return
        }
        // create a new macOS vm (headless)
        if initMacos || initMacosIPSW != "" {
            let delegate = CreateMacVM(cpus: cpus, ram: UInt64(mem), headless: false, resolution: resolution, vmdir: vmDir, netconf: net, sharing: virtiofs, initimg: initMacosIPSW, initDiskSize: initDiskSize)
            app.delegate = delegate
            app.run()
            return
        }
        // launch an existing macOS vm
        if FileManager.default.fileExists(atPath: vmDir + "/" + macOSMarker) {
            let delegate = MacVM(cpus: cpus, ram: UInt64(mem), headless: headless, resolution: resolution, vmdir: vmDir, netconf: net, sharing: virtiofs, initimg: initMacosIPSW, initDiskSize: initDiskSize)
            app.delegate = delegate
            app.run()
            return
        }
        print("No vm found: " + vmDir)
    }
}

vzcli.main()
