module usernet

go 1.26.0

require (
	github.com/containers/gvisor-tap-vsock v0.9.0
	golang.org/x/mobile v0.0.0-20261117202452-47699113848a
	golang.org/x/sync v0.25.0
)

// fixes issue with cpu usage on macOS with Zscaler
replace github.com/containers/gvisor-tap-vsock v0.8.8 => github.com/jdork0/gvisor-tap-vsock v0.0.0-20260315174211-b786921048b2

require (
	github.com/Microsoft/go-winio v0.6.2 // indirect
	github.com/google/btree v1.1.3 // indirect
	github.com/google/gopacket v1.1.19 // indirect
	github.com/inetaf/tcpproxy v0.0.0-20260515195445-c159a6051109 // indirect
	github.com/insomniacslk/dhcp v0.0.0-20250109001534-8abf58130905 // indirect
	github.com/linuxkit/virtsock v0.0.0-20220523201153-1a23e78aa7a2 // indirect
	github.com/mdlayher/socket v0.6.0 // indirect
	github.com/mdlayher/vsock v1.3.0 // indirect
	github.com/miekg/dns v1.1.73 // indirect
	github.com/pierrec/lz4/v4 v4.1.22 // indirect
	github.com/pkg/errors v0.9.1 // indirect
	github.com/sirupsen/logrus v1.10.2 // indirect
	github.com/u-root/uio v0.0.0-20240224005618-d2acac8f3701 // indirect
	golang.org/x/crypto v0.59.0 // indirect
	golang.org/x/exp v0.0.0-20231110203233-9a3e6036ecaa // indirect
	golang.org/x/mod v0.43.0 // indirect
	golang.org/x/net v0.63.0 // indirect
	golang.org/x/sys v0.50.0 // indirect
	golang.org/x/time v0.12.0 // indirect
	golang.org/x/tools v0.53.0 // indirect
	gvisor.dev/gvisor v0.0.0-20260413194555-9680d69bf798 // indirect
)
