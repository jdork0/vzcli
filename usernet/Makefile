XCFRAMEWORK = ../usernet.xcframework

.PHONY: all deps update build clean

all: build

deps:
	go install golang.org/x/mobile/cmd/gomobile@latest
	go mod tidy

update:
	go get $$(go list -m -f '{{if not (or .Indirect .Main)}}{{.Path}}@latest{{end}}' all)
	go mod tidy

build: deps
	gomobile init
	gomobile bind -target macos/arm64 -o $(XCFRAMEWORK)

clean:
	rm -rf $(XCFRAMEWORK)
