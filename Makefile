SCHEME = vzcli
CONFIGURATION = Release
XCFRAMEWORK = usernet.xcframework

.PHONY: all usernet build clean

all: usernet build

usernet:
	$(MAKE) -C usernet build

build: usernet
	xcodebuild -scheme $(SCHEME) -configuration $(CONFIGURATION) \
		CODE_SIGN_IDENTITY="Apple Development" \
		CODE_SIGN_STYLE=Automatic \
		DEVELOPMENT_TEAM=3JP8454SQ8 \
		build

clean:
	xcodebuild -scheme $(SCHEME) clean
	$(MAKE) -C usernet clean
