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

class CreateMacVM: MacVM {
    
    private var restoreImageURL: URL?
    private var downloadObserver: NSKeyValueObservation?
    private var installationObserver: NSKeyValueObservation?
    
    override init(cpus: Int, ram: UInt64, headless: Bool, resolution: String, vmpath: String, netconf: String, sharing: String, initimg: String, initDiskSize: UInt64) {
        super.init(cpus: cpus, ram: ram, headless: headless, resolution: resolution, vmpath: vmpath, netconf: netconf, sharing: sharing, initimg: initimg, initDiskSize: initDiskSize)
        vmTypePath = self.vmBundlePath + macOSMarker
    }
    
    override func applicationDidFinishLaunching(_ aNotification: Notification) {
        // create the vm directory
        createVMBundle()
        // create an empty disk image
        createMainDiskImage()
        // install macOS from restore image or download latest
        if initImg != "" {
            // install from given image
            restoreImageURL = URL(fileURLWithPath: initImg)
            installMacOS(ipswURL: restoreImageURL!)
        } else {
            // download latest image and install from that
            download {
                self.restoreImageURL = URL(fileURLWithPath: self.vmBundlePath + "RestoreImage.ipsw")
                self.installMacOS(ipswURL: self.restoreImageURL!)
            }
        }
    }

    public func download(completionHandler: @escaping () -> Void) {
        print("Attempting to download latest available restore image.")
        VZMacOSRestoreImage.fetchLatestSupported { [self](result: Result<VZMacOSRestoreImage, Error>) in
            switch result {
                case let .failure(error):
                    print(error.localizedDescription)
                    exit(1)
                case let .success(restoreImage):
                    downloadRestoreImage(restoreImage: restoreImage, completionHandler: completionHandler)
            }
        }
    }

    private func downloadRestoreImage(restoreImage: VZMacOSRestoreImage, completionHandler: @escaping () -> Void) {
        let downloadTask = URLSession.shared.downloadTask(with: restoreImage.url) { localURL, response, error in
            if let error = error {
                print("Download failed. \(error.localizedDescription).")
                exit(1)
            }

            guard (try? FileManager.default.moveItem(at: localURL!, to: self.restoreImageURL!)) != nil else {
                print("Failed to move downloaded restore image to \(self.restoreImageURL!).")
                exit(1)
            }
            print(" done.")
            completionHandler()
        }

        var downloadProgress = 0
        downloadObserver = downloadTask.progress.observe(\.fractionCompleted, options: [.initial, .new]) { (progress, change) in
            let floorValue = Int(floor(change.newValue! * 100))
            if downloadProgress != floorValue {
                downloadProgress = floorValue
                print("Restore image download progress: " + String(floorValue) + "%%")
            }
        }
        downloadTask.resume()
    }

    public func installMacOS(ipswURL: URL) {
        print("Attempting to install from IPSW at \(ipswURL).")
        VZMacOSRestoreImage.load(from: ipswURL, completionHandler: { [self](result: Result<VZMacOSRestoreImage, Error>) in
            switch result {
                case let .failure(error):
                    print(error.localizedDescription)
                    exit(1)
                case let .success(restoreImage):
                    installMacOS(restoreImage: restoreImage)
            }
        })
    }

    private func installMacOS(restoreImage: VZMacOSRestoreImage) {
        guard let macOSConfiguration = restoreImage.mostFeaturefulSupportedConfiguration else {
            print("No supported configuration available.")
            exit(1)
        }

        if !macOSConfiguration.hardwareModel.isSupported {
            print("macOSConfiguration configuration isn't supported on the current host.")
            exit(1)
        }

        DispatchQueue.main.async { [self] in
            createMainDiskImage()
            createVirtualMachine(macOSConfiguration: macOSConfiguration)
            startInstallation(restoreImageURL: restoreImage.url)
        }
    }

    private func startInstallation(restoreImageURL: URL) {
        let installer = VZMacOSInstaller(virtualMachine: virtualMachine, restoringFromImageAt: restoreImageURL)

        print("Starting installation.")
        installer.install(completionHandler: { (result: Result<Void, Error>) in
            if case let .failure(error) = result {
                print(error.localizedDescription)
                exit(1)
            } else {
                print("Installation succeeded.")
            }
        })

        // Observe installation progress
        var installProgress = 0
        installationObserver = installer.progress.observe(\.fractionCompleted, options: [.initial, .new]) { (progress, change) in
            let floorValue = Int(floor(change.newValue! * 100))
            if installProgress != floorValue {
                installProgress = floorValue
                print("Installation progress: " + String(floorValue) + "%%")
            }
        }
    }

}
