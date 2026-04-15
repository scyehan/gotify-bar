APP_NAME = GotifyBar
CONFIG ?= debug
BUILD_DIR = .build/$(CONFIG)
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
BUNDLE_ID = com.kaede.gotifybar
INSTALL_DIR = /Applications
APP_VERSION ?= 1.0

ICON_SOURCE = Resources/AppIcon-1024.png
ICONSET = Resources/AppIcon.iconset
ICNS = Resources/AppIcon.icns

.PHONY: build bundle install run clean icon

build:
	swift build -c $(CONFIG)

icon: $(ICNS)

$(ICNS): $(ICON_SOURCE)
	@rm -rf "$(ICONSET)"
	@mkdir -p "$(ICONSET)"
	@sips -z 16 16     "$(ICON_SOURCE)" --out "$(ICONSET)/icon_16x16.png"      > /dev/null
	@sips -z 32 32     "$(ICON_SOURCE)" --out "$(ICONSET)/icon_16x16@2x.png"   > /dev/null
	@sips -z 32 32     "$(ICON_SOURCE)" --out "$(ICONSET)/icon_32x32.png"      > /dev/null
	@sips -z 64 64     "$(ICON_SOURCE)" --out "$(ICONSET)/icon_32x32@2x.png"   > /dev/null
	@sips -z 128 128   "$(ICON_SOURCE)" --out "$(ICONSET)/icon_128x128.png"    > /dev/null
	@sips -z 256 256   "$(ICON_SOURCE)" --out "$(ICONSET)/icon_128x128@2x.png" > /dev/null
	@sips -z 256 256   "$(ICON_SOURCE)" --out "$(ICONSET)/icon_256x256.png"    > /dev/null
	@sips -z 512 512   "$(ICON_SOURCE)" --out "$(ICONSET)/icon_256x256@2x.png" > /dev/null
	@sips -z 512 512   "$(ICON_SOURCE)" --out "$(ICONSET)/icon_512x512.png"    > /dev/null
	@cp "$(ICON_SOURCE)" "$(ICONSET)/icon_512x512@2x.png"
	@iconutil -c icns "$(ICONSET)" -o "$(ICNS)"
	@rm -rf "$(ICONSET)"
	@echo "Built $(ICNS)"

bundle: build $(ICNS)
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	@cp "$(ICNS)" "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
	@/usr/libexec/PlistBuddy -c "Add :CFBundleName string $(APP_NAME)" "$(APP_BUNDLE)/Contents/Info.plist"
	@/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $(BUNDLE_ID)" "$(APP_BUNDLE)/Contents/Info.plist"
	@/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $(APP_VERSION)" "$(APP_BUNDLE)/Contents/Info.plist"
	@/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $(APP_VERSION)" "$(APP_BUNDLE)/Contents/Info.plist"
	@/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $(APP_NAME)" "$(APP_BUNDLE)/Contents/Info.plist"
	@/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$(APP_BUNDLE)/Contents/Info.plist"
	@/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$(APP_BUNDLE)/Contents/Info.plist"
	@/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$(APP_BUNDLE)/Contents/Info.plist"
	@/usr/libexec/PlistBuddy -c "Add :NSUserNotificationAlertStyle string alert" "$(APP_BUNDLE)/Contents/Info.plist"
	@/usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" "$(APP_BUNDLE)/Contents/Info.plist"
	@/usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSAllowsArbitraryLoads bool true" "$(APP_BUNDLE)/Contents/Info.plist"
	@echo "Built $(APP_BUNDLE)"

run: bundle
	@open "$(APP_BUNDLE)"

install: bundle
	@rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME).app"

clean:
	swift package clean
	@rm -rf "$(APP_BUNDLE)" "$(ICNS)" "$(ICONSET)"
