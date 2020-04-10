###############################################
#
# Makefile
#
###############################################

# Default is to run a clean build and test
.DEFAULT_GOAL := build

DEVELOPER := Marc_Lavergne
WORKSPACE := Demo
SCHEME := Build
VERSION := 1.0


UDID := a6a7851a100d9ad8888a14d5f2df1b84aba2a658
IOS_VER := 13.0

XCDEST := platform=iOS,id=${UDID},OS=${IOS_VER}
# XCDEST := platform=iOS Simulator,name=iPhone Xʀ,OS=${IOS_VER}
# XCDEST := generic/platform=iOS

SDK := iphoneos
# SDK := iphonesimulator

#
# Setup helpers
# 

setup:
	sudo gem install xcpretty

devices:
	instruments -s devices

schemes:
	xcodebuild -workspace ${WORKSPACE}.xcworkspace -list

#
# Build targets
#

build:
	xcodebuild test -workspace ${WORKSPACE}.xcworkspace -scheme ${SCHEME} -destination "$(XCDEST)" | xcpretty

tbuild:
	xcodebuild -workspace ${WORKSPACE}.xcworkspace -scheme ${SCHEME} -destination ${XCDEST} build-for-testing | xcpretty

sinstall:
	xcrun simctl install booted ~/src/ios/sim/Applications/${SCHEME}.app

sim:
	xcrun instruments -w "iPhone Xʀ (${IOS_VER} Simulator)"


package:
	xcrun -sdk ${SDK} PackageApplication -o "${IPA_DIR}/${WORKSPACE}.ipa" -verbose "${WORKSPACE}.app" -sign "iPhone Distribution: ${DEVELOPER}" --embed "${DEVELOPER}_Ad_Hoc.mobileprovision"

#
# IPA targets
#

archive:
	xcodebuild -workspace ${WORKSPACE}.xcworkspace -scheme ${SCHEME} -sdk ${SDK} -configuration AdHoc archive -archivePath $(PWD)/dist/${WORKSPACE}.xcarchive

ipa:
	xcodebuild -exportArchive -archivePath $(PWD)/dist/${WORKSPACE}.xcarchive -exportOptionsPlist exportOptions.plist -exportPath $(PWD)/dist

reipa:
	unzip ${WORKSPACE}.ipa
	/usr/bin/codesign -f -s "iPhone Distribution: Company Name" --resource-rules "Payload/${WORKSPACE}.app/ResourceRules.plist" "Payload/${WORKSPACE}.app"
	zip -qr "${WORKSPACE}.resigned.ipa" Payload

#
# TestFlight
#

testflight:
	curl "http://testflightapp.com/api/builds.json" -F file=@"${IPA_DIR}/${WORKSPACE}.ipa" -F dsym=@"${IPA_DIR}/${WORKSPACE}.dSYM.zip" -F api_token="${API_TOKEN}" -F team_token="${TEAM_TOKEN}" -F notes="Build ${VERSION} uploaded automatically from Xcode." -F notify=True -F distribution_lists='all'
