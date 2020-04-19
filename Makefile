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
	xcrun altool --store-password-in-keychain-item ADP --username ${USERNAME} --password DEVELOPER_TOOLS_PASSWORD

# ##############################################################################
# Keychain
#

# list ADP certs
certs:
	security find-identity -p basic -v

certdelete:
	security delete-certificate -Z TOKEN_HASH

certadd:
	security import FILE

import:
	security import key.pem -k ~/Library/Keychains/login.keychain

export:
	echo -n ${PASSWORD} | pbcopy
	security export -t privKeys -k login.keychain -f pkcs12 -o privKeys.p12

keychain:
	open -a Keychain\ Access

# not used
savepass:
	security add-generic-password

# not used
getpass:
	security find-generic-password -D "application password"

profiles:
	ls ~/Library/MobileDevice/Provisioning\ Profiles

MPID := d854e6ef-f4be-42b7-9451-568e18812531.mobileprovision
dump:
	strings ~/Library/MobileDevice/Provisioning\ Profiles/${MPID} | grep -A 10 AppIDName

# ##############################################################################
# Xcode targets
#

schemes:
	xcodebuild -workspace ${WORKSPACE}.xcworkspace -list

build:
	xcodebuild -workspace ${WORKSPACE}.xcworkspace -scheme ${SCHEME} -destination "$(XCDEST)" build | xcpretty

test:
	xcodebuild -workspace ${WORKSPACE}.xcworkspace -scheme ${SCHEME} -destination "$(XCDEST)" test | xcpretty

testbuild:
	xcodebuild -workspace ${WORKSPACE}.xcworkspace -scheme ${SCHEME} -destination ${XCDEST} build-for-testing | xcpretty

# ##############################################################################
# Devices
#

devices:
	instruments -s devices

sinstall:
	xcrun simctl install booted ./dist/${WORKSPACE}.app

sim:
	xcrun instruments -w "iPhone Xʀ (${IOS_VER} Simulator)"

# ##############################################################################
# IPA targets
#

archive:
	xcodebuild -workspace ${WORKSPACE}.xcworkspace -scheme ${SCHEME} -sdk ${SDK} -configuration AdHoc archive -archivePath ./dist/${WORKSPACE}.xcarchive

ipa:
	xcodebuild -exportArchive -archivePath ./dist/${WORKSPACE}.xcarchive -exportOptionsPlist exportOptions.plist -exportPath ./dist

SIGNID := "iPhone Distribution: ${DEVNAME}"
reipa:
	unzip ${WORKSPACE}.ipa
	codesign -f --sign "${SIGNID}" --resource-rules "Payload/${WORKSPACE}.app/ResourceRules.plist" "Payload/${WORKSPACE}.app"
	zip -qr "${WORKSPACE}.resigned.ipa" Payload

ipasign:
	xcrun -sdk ${SDK} PackageApplication -o "${IPA_DIR}/${WORKSPACE}.ipa" -verbose "${WORKSPACE}.app" -sign "iPhone Distribution: ${DEVNAME}" --embed "${DEVELOPER}_Ad_Hoc.mobileprovision"

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

codesign:
	codesign -f -o runtime --timestamp --sign "Developer ID Application: ${DEVNAME} (${DEVID})" build/demo

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

pkgbuild:
	pkgbuild --version $(VERSION) --identifier $(IDENTIFIER) --install-location /usr/local/bin --root build ${WORKSPACE}.pkg

pkgsign:
	productsign --sign "Developer ID Installer: ${DEVNAME} (${DEVID})" ${WORKSPACE}.pkg ${WORKSPACE}-signed.pkg

pkgvalidate:
	codesign -dvv build/demo
	pkgutil --check-signature ${WORKSPACE}.pkg

pkgnote:
	xcrun altool --notarize-app --type osx --primary-bundle-id ${IDENTIFIER} --username "${USERNAME}" --password "@keychain:ADP" --file ${WORKSPACE}.pkg

NOTEUUID = xxxx-xxxx-xxxx-xxxx
notestatus:
	xcrun altool --notarization-info "${NOTEUUID}" --username ${USERNAME} --password "@keychain:ADP"

staple:
	xcrun stapler staple ${WORKSPACE}.pkg

pkglist:
	pkgutil --payload-files ${WORKSPACE}.pkg

pkginstall:
	spctl -a -vv -t install ${WORKSPACE}.pkg

pkguninstall:
	sudo pkgutil --forget $(IDENTIFIER)
