PREFIX ?= $(HOME)/.local
DEVELOPER_DIRECTORY := $(shell xcode-select -p)
TESTING_FRAMEWORKS := $(DEVELOPER_DIRECTORY)/Library/Developer/Frameworks

ifeq ($(notdir $(DEVELOPER_DIRECTORY)),CommandLineTools)
SWIFT_TESTING_FLAGS := \
	-Xswiftc -F -Xswiftc $(TESTING_FRAMEWORKS) \
	-Xswiftc -plugin-path -Xswiftc $(DEVELOPER_DIRECTORY)/usr/lib/swift/host/plugins/testing \
	-Xlinker -F -Xlinker $(TESTING_FRAMEWORKS) \
	-Xlinker -rpath -Xlinker $(TESTING_FRAMEWORKS) \
	-Xlinker -rpath -Xlinker $(DEVELOPER_DIRECTORY)/Library/Developer/usr/lib
endif

.PHONY: build test install uninstall

build:
	swift build -c release

test:
	swift test $(SWIFT_TESTING_FLAGS)

install: build
	install -d "$(PREFIX)/bin"
	install -m 755 .build/release/osnip "$(PREFIX)/bin/osnip"

uninstall:
	rm -f "$(PREFIX)/bin/osnip"
