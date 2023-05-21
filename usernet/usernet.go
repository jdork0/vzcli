package usernet

import (
	"context"
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"os"
	"strings"

	"github.com/containers/gvisor-tap-vsock/pkg/types"
	"github.com/containers/gvisor-tap-vsock/pkg/virtualnetwork"
	"github.com/sirupsen/logrus"
	"golang.org/x/sync/errgroup"
)

func StartUserNet(sockFD int32, portForwards string) {

	// portForwards format
	// hostport:guestport (assumes 127.0.0.1 and 172.16.10.2)
	// hostip:port:guestip:port

	var portFwdMap = make(map[string]string)
	if portForwards != "" {
		for _, portForward := range strings.Split(portForwards, ",") {
			if strings.Count(portForward, ":") == 1 {
				hostFwd := fmt.Sprintf("127.0.0.1:%s", strings.Split(portForward, ":")[0])
				guestFwd := fmt.Sprintf("172.16.10.2:%s", strings.Split(portForward, ":")[1])
				portFwdMap[hostFwd] = guestFwd
			} else if strings.Count(portForward, ":") == 3 {
				hostFwd := fmt.Sprintf("%s:%s", strings.Split(portForward, ":")[0], strings.Split(portForward, ":")[1])
				guestFwd := fmt.Sprintf("%s:%s", strings.Split(portForward, ":")[2], strings.Split(portForward, ":")[3])
				portFwdMap[hostFwd] = guestFwd
			} else {
				fmt.Printf("err: invalid port forward entry: %s", portForward)
			}
		}
	} else {
		portFwdMap = nil
	}

	// gvisor net config
	config := types.Configuration{
		Debug:             false,
		MTU:               1500,
		Subnet:            "172.16.10.0/24",
		GatewayIP:         "172.16.10.1",
		GatewayMacAddress: "5a:94:ef:e4:0c:dd",
		DHCPStaticLeases:  nil,
		Forwards:          portFwdMap,
		DNS:               []types.Zone{},
		DNSSearchDomains:  nil,
		NAT: map[string]string{
			"172.16.10.254": "127.0.0.1",
		},
		GatewayVirtualIPs: []string{"172.16.10.254"},
		Protocol:          types.BessProtocol,
	}

	// try to turn off golang logging
	null, _ := os.Open(os.DevNull)
	os.Stdout = null
	os.Stderr = null
	logrus.SetOutput(ioutil.Discard)
	log.SetOutput(ioutil.Discard)

	// create a virtual network
	vn, err := virtualnetwork.New(&config)
	if err != nil {
		fmt.Printf("err: %q\n", err)
	}

	// create a background context
	ctx := context.Background()

	// get a file connection to the socket file descriptor
	file := os.NewFile(uintptr(sockFD), "server")
	conn, err := net.FileConn(file)
	if err != nil {
		fmt.Printf("err: %q\n", err)
	}

	// connect the socket to the virtualnetwork
	groupErrs, ctx := errgroup.WithContext(ctx)
	groupErrs.Go(func() error {
		return vn.AcceptBess(ctx, conn)
	})
	go func() {
		err := groupErrs.Wait()
		if err != nil {
			fmt.Printf("virtual network error: %q\n", err)
		}
	}()
}
