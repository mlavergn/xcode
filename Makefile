###############################################
#
# Makefile
#
###############################################

# Default is to run a clean build and test
.DEFAULT_GOAL = build

DEVNAME = Marc Lavergne
DEVID = Q6H2FB9YW2
DEVELOPER := $(shell echo ${DEVNAME} | sed 's/ /_/')

WORKSPACE = Demo
SCHEME = Build
VERSION = 1.0

UDID = 00008020-00024cac02b8003a
IOS_VER = 13.0

XCDEST := platform=iOS,id=${UDID},OS=${IOS_VER}
# XCDEST := platform=iOS Simulator,name=iPhone Xʀ,OS=${IOS_VER}
# XCDEST := generic/platform=iOS

SDK ?= iphoneos
# SDK := iphonesimulator

#
# Setup helpers
# 

setup:
	sudo gem install xcpretty

devices:
	instruments -s devices

certs:
	security find-identity -p basic -v

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
	xcrun -sdk ${SDK} PackageApplication -o "${IPA_DIR}/${WORKSPACE}.ipa" -verbose "${WORKSPACE}.app" -sign "iPhone Distribution: ${DEVNAME}" --embed "${DEVELOPER}_Ad_Hoc.mobileprovision"

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



# ##############################################################################
# MacOS
#


USERNAME = "mlavergne@gmail.com"
PASSWORD ?= ""

BUNDLEID = "com.marclavergne.Demo"

#
# Signing
#

# adhoc macos pkg distbution
signpkg:
	productsign --sign "Developer ID Installer: ${DEVNAME} (${DEVID})" ${WORKSPACE}-${VERSION}-tmp.pkg ${WORKSPACE}-${VERSION}.pkg

# adhoc macos app distribution
signmac:
	codesign --deep --force --verbose --sign "Developer ID Installer: ${DEVNAME} (${DEVID})" ${WORKSPACE}.app
	codesign --verify -vvvv ${WORKSPACE}.app
	spctl -a -vvvv ${WORKSPACE}.app

# store the altool password in the keychain
addpass:
	xcrun altool --store-password-in-keychain-item ADP --username ${USERNAME} --password "${PASSWORD}"

notarize:
	xcrun altool --notarize-app --type macos --primary-bundle-id ${IDENTIFIER} --asc-provider ${DEVID} --username "${USERNAME}" --password "@keychain:ADP" --file ${WORKSPACE}.app}

staple:
	xcrun stapler staple -v ${WORKSPACE}.app

validate:
	xcrun altool --validate-app --type macos --file ${WORKSPACE}.app --username ${USERNAME} --password "${PASSWORD}"

uploadmac:
	xcrun altool --upload-app --type macos --file ${WORKSPACE}.app --username ${USERNAME} --password "${PASSWORD}"


# ##############################################################################
# TestFlight
#

API_TOKEN = ""
TEAM_TOKEN = ""

tftoken:
	open "https://appstoreconnect.apple.com"

testflight:
	curl "http://testflightapp.com/api/builds.json" -F file=@"${IPA_DIR}/${WORKSPACE}.ipa" -F dsym=@"${IPA_DIR}/${WORKSPACE}.dSYM.zip" -F api_token="${API_TOKEN}" -F team_token="${TEAM_TOKEN}" -F notes="Build ${VERSION} uploaded automatically from Xcode." -F notify=True -F distribution_lists='all'
	
