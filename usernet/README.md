# Building notes

## Prerequisites
- Install [Homebrew](https://brew.sh)
- `brew install go`
- Ensure `$GOPATH/bin` is in your `PATH`

## Build
From the `usernet/` directory:
```
make
```

This will install `gomobile`, fetch required dependencies (`golang.org/x/mobile/bind` packages), and build the `usernet.xcframework`.

Alternatively, from the project root:
```
make usernet
```

## Clean
```
make clean
```
