VERSION ?= 0.0.0
RESTIC_BINARY ?= restic

all:
	xcodebuild -workspace ResticScheduler.xcodeproj/project.xcworkspace -scheme 'Restic Scheduler' -configuration Release -derivedDataPath $(PWD)

disable-code-signing:
	/usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.disable-library-validation bool True" ResticScheduler/ResticScheduler.entitlements 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :com.apple.security.cs.disable-library-validation True" ResticScheduler/ResticScheduler.entitlements
	/usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.disable-library-validation bool True" ResticRunner/ResticRunner.entitlements 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :com.apple.security.cs.disable-library-validation True" ResticRunner/ResticRunner.entitlements
	echo "CODE_SIGN_STYLE = Manual\nMARKETING_VERSION = $(VERSION)\nAPP_BUNDLE_ID = ru.makinen.ResticScheduler\nAPP_RESTIC_BINARY = $(RESTIC_BINARY)" > Config.xcconfig

clean:
	rm -rf Build Logs ModuleCache.noindex SDKStatCaches.noindex info.plist
