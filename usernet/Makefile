XCFRAMEWORK = ../usernet.xcframework

.PHONY: all deps build clean

all: build

deps:
	go install golang.org/x/mobile/cmd/gomobile@latest
	go mod tidy

build: deps
	gomobile init
	gomobile bind -target macos/arm64 -o $(XCFRAMEWORK)

clean:
	rm -rf $(XCFRAMEWORK)
