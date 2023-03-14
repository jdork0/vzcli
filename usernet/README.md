# Building notes
- install homebrew
- brew install go
- setup path for go
- go install golang.org/x/mobile/cmd/gomobile@latest
- gomobile init
- cd /path/to/usernet
- gomobile bind -target macos/arm64 -o ../usernet.xcframework

