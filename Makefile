###############################################
#
# Makefile
#
###############################################

# Default is to run a clean build and test
.DEFAULT_GOAL = build

USERNAME = "mlavergne@gmail.com"
PASSWORD ?= ""

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

# ##############################################################################
# Setup
#

setup:
	sudo gem install xcpretty

# generate app-specific password
apppasswd:
	open "https://appleid.apple.com/account/manage"

# save app-specific password to keychain
appsave:
	xcrun altool --store-password-in-keychain-item ADP --username ${USERNAME} --password "@keychain:ADP"

# list development devices
devices:
	instruments -s devices

# list ADP certs
certs:
	security find-identity -p basic -v

# ##############################################################################
# Build targets
#

schemes:
	xcodebuild -workspace ${WORKSPACE}.xcworkspace -list

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

# ##############################################################################
# IPA targets
#

archive:
	xcodebuild -workspace ${WORKSPACE}.xcworkspace -scheme ${SCHEME} -sdk ${SDK} -configuration AdHoc archive -archivePath $(PWD)/dist/${WORKSPACE}.xcarchive

ipa:
	xcodebuild -exportArchive -archivePath $(PWD)/dist/${WORKSPACE}.xcarchive -exportOptionsPlist exportOptions.plist -exportPath $(PWD)/dist

SIGNID := "iPhone Distribution: ${DEVNAME}"
reipa:
	unzip ${WORKSPACE}.ipa
	codesign -f --sign "${SIGNID}" --resource-rules "Payload/${WORKSPACE}.app/ResourceRules.plist" "Payload/${WORKSPACE}.app"
	zip -qr "${WORKSPACE}.resigned.ipa" Payload

# ##############################################################################
# MacOS
#

IDENTIFIER = "com.marclavergne.Demo"

SIGNID := "Developer ID Installer: ${DEVNAME} (${DEVID})"
#
# Signing
#

# adhoc macos app distribution
signmac:
	codesign --deep --force --verbose --sign "${SIGNID}" ${WORKSPACE}.app
	codesign --verify -vvvv ${WORKSPACE}.app
	spctl -a -vvvv ${WORKSPACE}.app

notarize:
	xcrun altool --notarize-app --type macos --primary-bundle-id ${IDENTIFIER} --asc-provider ${DEVID} --username "${USERNAME}" --password "@keychain:ADP" --file ${WORKSPACE}.app}

staple:
	xcrun stapler staple -v ${WORKSPACE}.app

validate:
	xcrun altool --validate-app --type macos --file ${WORKSPACE}.app --username ${USERNAME} --password "@keychain:ADP"

uploadmac:
	xcrun altool --upload-app --type macos --file ${WORKSPACE}.app --username ${USERNAME} --password "@keychain:ADP"


# ##############################################################################
# TestFlight
#

API_TOKEN = ""
TEAM_TOKEN = ""

tftoken:
	open "https://appstoreconnect.apple.com"

testflight:
	curl "http://testflightapp.com/api/builds.json" -F file=@"${IPA_DIR}/${WORKSPACE}.ipa" -F dsym=@"${IPA_DIR}/${WORKSPACE}.dSYM.zip" -F api_token="${API_TOKEN}" -F team_token="${TEAM_TOKEN}" -F notes="Build ${VERSION} uploaded automatically from Xcode." -F notify=True -F distribution_lists='all'

# ##############################################################################
# Packages
#

codesign:
	codesign -f -o runtime --timestamp --sign "Developer ID Application: ${DEVNAME} (${DEVID})" build/demo

pkgbuild:
	pkgbuild --version $(VERSION) --identifier $(IDENTIFIER) --install-location /usr/local/bin --root build ${WORKSPACE}.pkg

pkgsign:
	productsign --sign "Developer ID Installer: ${DEVNAME} (${DEVID})" ${WORKSPACE}.pkg ${WORKSPACE}-signed.pkg

pkgvalidate:
	codesign -dvv build/demo
	pkgutil --check-signature ${WORKSPACE}.pkg

pkgnotarize:
	xcrun altool --notarize-app --type osx --primary-bundle-id ${IDENTIFIER} --username "${USERNAME}" --password "@keychain:ADP" --file ${WORKSPACE}.pkg

NTZUUID = xxxx-xxxx-xxxx-xxxx
status:
	xcrun altool --notarization-info "${NTZUUID}" --username ${USERNAME} --password "@keychain:ADP"

staple:
	xcrun stapler staple ${WORKSPACE}.pkg

pkglist:
	pkgutil --payload-files ${WORKSPACE}.pkg

pkginstall:
	spctl -a -vv -t install ${WORKSPACE}.pkg

pkguninstall:
	sudo pkgutil --forget $(IDENTIFIER)
