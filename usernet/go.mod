module usernet

go 1.25.0

require (
	github.com/containers/gvisor-tap-vsock v0.8.8
	golang.org/x/mobile v0.0.0-20260312152759-81488f6aeb60
	golang.org/x/sync v0.20.0
)

// fixes issue with cpu usage on macOS with Zscaler
replace github.com/containers/gvisor-tap-vsock v0.8.8 => github.com/jdork0/gvisor-tap-vsock v0.0.0-20260315174211-b786921048b2

require (
	github.com/Microsoft/go-winio v0.6.2 // indirect
	github.com/apparentlymart/go-cidr v1.1.0 // indirect
	github.com/google/btree v1.1.3 // indirect
	github.com/google/gopacket v1.1.19 // indirect
	github.com/inetaf/tcpproxy v0.0.0-20250222171855-c4b9df066048 // indirect
	github.com/insomniacslk/dhcp v0.0.0-20250109001534-8abf58130905 // indirect
	github.com/miekg/dns v1.1.72 // indirect
	github.com/pierrec/lz4/v4 v4.1.22 // indirect
	github.com/sirupsen/logrus v1.9.4 // indirect
	github.com/u-root/uio v0.0.0-20240224005618-d2acac8f3701 // indirect
	golang.org/x/crypto v0.49.0 // indirect
	golang.org/x/mod v0.34.0 // indirect
	golang.org/x/net v0.52.0 // indirect
	golang.org/x/sys v0.42.0 // indirect
	golang.org/x/time v0.11.0 // indirect
	golang.org/x/tools v0.43.0 // indirect
	gvisor.dev/gvisor v0.0.0-20240916094835-a174eb65023f // indirect
)
