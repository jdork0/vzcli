# vzcli
Command line app for running arm64 Linux / macOS Virtual Machines using Apple Virtualization Framework.

The purpose of this project was to provide a quick command line method to create/launch Linux or macOS virtual machines using the virtualization framework available in macOS 13 Ventura.

**Only arm64 supported.** 

# Usage notes

Apple signing requires this be distributed as an app bundle.  I use an alias to simplify accessing the command line app.
```
$ alias vzcli='/Applications/vzcli.app/Contents/MacOS/vzcli'
$ vzcli ...
```

# Features

## Networking

- _user_: a user networking stack based on https://github.com/containers/gvisor-tap-vsock.  Uses VZFileHandleNetworkDeviceAttachment for socket based networking where the VM is only reachable through port forwards.  This is the default networking stack.  See the usage for port forwarding examples.

- _nat_: Apple's NAT network sharing.  macOS will create a bridge100 interface and the VM will get an address on the 192.168.205.0/24 subnet. NAT networking must specify a MAC address for the guest interface.

- _bridged_: Bridged networking.  This works on the signed release binaries, but will not work if you build the code yourself without getting the com.apple.vm.networking entitlement from Apple.  Bridged networking must specify the interface to bridge and the MAC address that will be assigned to the vm.

The ```'vzcli --generate-mac .'``` command can be used generate a random MAC address for use with NAT or Bridged networking.

Multiple network interfaces can be configured on the VM by chaining the configurations with the ```+``` character.  See usage below.

## Directory sharing

Directories can be shared via virtiofs flag with the _tag_:_direcory_:_ro|rw_ format.  Linux VMs that want to use rosetta to run Intel binaries can use the _rosetta_ tag.  Multiple shares can be specified with the ```+``` syntax.

Shares can be mounted in macOS / Linux using the specified tag:

### *macOS*:
```
# launch existing macOS vm
$ vzcli --virtiofs home:/Users/test:ro ~/vm/macos/

# inside macOS
$ mkdir /path/to/mnt/dir
$ sudo mount_virtiofs home /path/to/mnt/dir
```
### *Linux*:
```
# launch existing Linux vm
$ vzcli --virtiofs rosetta+home:/Users/test:ro ~/vm/ubuntu/

# inside Linux
$ mkdir /path/to/mnt/dir
$ sudo mount -t virtiofs home /path/to/mnt/home
$ sudo mount -t virtiofs rosetta /path/to/mnt/rosetta
```
# Creating Virtual Machines
## Linux

Creating a Linux VM will require using the install ISO of your favourite distro.  When creating a VM, the vm-path directory must not alreay exist.

```
$ vzcli --init-linux ~/vm/iso/ubuntu.iso ~/vm/ubuntu
```

## macOS

macOS VMs must be created with the ```--init-macos``` flag.  By default this will download the latest macOS version restore file and use that to create the VM.  A restore ipsw file can be pre-downloaded and used to perform the install using the``` --init-macos-ipsw```.  When creating a VM, the vm-path directory must not alreay exist.

```
# create with latest restore file
$ vzcli --init-macos ~/vm/macOS
# create with specific restore file
$vzcli --init-macos-ipsw /path/to/restore.ipsw ~/vm/macOS
```
After it is installed successfully, it can be started with:
```
$ vzcli ~/vm/macOS
```

NOTE: If the ```--resolution``` flag contains a DPI >= 200 the display will be scaled by the scaling factor of the display.  On a retina macbook, a 1200x800x224 resolution will create a window sized 1200x800, but the VM will be running at 2400x1600 within that window for a sharper display.

## Usage

```
USAGE: vzcli [--cpus <cpus>] [--mem <mem>] [--resolution <resolution>] [--net <net>] [--virtiofs <virtiofs>] [--headless] [--init-linux <init-linux>] [--init-macos] [--init-macos-ipsw <init-macos-ipsw>] [--init-disk-size <init-disk-size>] [--generate-mac] <vm-path>

ARGUMENTS:
  <vm-path>               Path to VM directory

OPTIONS:
  --cpus <cpus>           Number of cpus. (default: 4)
  --mem <mem>             RAM in MB. (default: 8192)
  --resolution <resolution>
                          Display resolution [width x height x dpi] (dpi macOS only) (default: 1280x800x224)
  --net <net>             List of type:options
                            user:[host:<hostport>:<guestport>,<hostport2>:<guestport2>,...]
                            bridged:interface:mac
                            nat:mac
                          example: --net user:2222,22+bridged:en0:2e:1c:46:7a:f8:68
                           (default: user)
  --virtiofs <virtiofs>   List of directories exposed to guest by virtiofs
                            rosetta (linux rosetta support)
                            tag:directory:ro|rw
                          example: --virtiofs rosetta+home:/Users/test/test:rw

  --headless              No GUI
  --init-linux <init-linux>
                          Path to Linux install iso
  --init-macos            Create a new macOS VM
  --init-macos-ipsw <init-macos-ipsw>
                          Use specified restore.ipsw instead of downloading latest.
  --init-disk-size <init-disk-size>
                          Disk size in GB. (default: 64)
  --generate-mac          Generate a MAC Address to use with bridged networking.
  -h, --help              Show help information.
```
