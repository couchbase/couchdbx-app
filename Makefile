#
# To make the couchbase server app bundle, use:
#   make couchbase-server-zip BUILD_ENTERPRISE=TRUE
#
# If you just want to quickly make the Couchbase Server.app file, do:
#   make couchbase-server BUILD_ENTERPRISE=TRUE
#
# The .app file will be created in couchdbx-app/build/Release
#

all: couchbase-server version_text

couchbase-server: license readme cb.plist InfoPlist.strings
	xcodebuild -target 'Couchbase Server' -configuration Release

couchbase-server-zip: license readme cb.plist InfoPlist.strings
	xcodebuild -target 'Couchbase Server Zip' -configuration Release

version_text: couchbase-server
	echo "0.0.0-0000" > build/Release/Couchbase\ Server.app/Contents/Resources/couchbase-core/VERSION.txt

cb.plist: cb.plist.tmpl
	sed 's/@SHORT_VERSION@/$(if $(PRODUCT_VERSION),$(shell echo $(PRODUCT_VERSION) | cut -d- -f1),"0.0.0")/g; s/@VERSION@/$(if $(PRODUCT_VERSION),$(PRODUCT_VERSION),"0.0.0-1000")/g' $< > $@
	cp cb.plist "Couchbase Server/Couchbase Server-Info.plist"

InfoPlist.strings: InfoPlist.strings.tmpl
	sed 's/@COPYRIGHT_YEAR@/$(shell date +%Y)/g' $< > $@
	mkdir "Couchbase Server/en.lproj"
	cp InfoPlist.strings "Couchbase Server/en.lproj/InfoPlist.strings"

license:
ifeq ($(BUILD_ENTERPRISE),FALSE)
	cp ../product-texts/couchbase-server/license/ce-license.txt  "Couchbase Server/LICENSE.txt"
	cp ../product-texts/couchbase-server/license/ce-license.html "Couchbase Server/Credits.html"
else
ifeq ($(BUILD_ENTERPRISE),TRUE)
	cp ../product-texts/couchbase-server/license/ee-license.txt  "Couchbase Server/LICENSE.txt"
	cp ../product-texts/couchbase-server/license/ee-license.html "Couchbase Server/Credits.html"
else
	$(error "You must specify either BUILD_ENTERPRISE=FALSE or BUILD_ENTERPRISE=TRUE")
endif
endif

readme:
	cp ../product-texts/couchbase-server/readme/README.txt  "Couchbase Server/README.txt"	

clean:
	(cd "Couchbase Server" && rm -f Credits.html LICENSE.txt README.txt)
	xcodebuild -target 'Couchbase Server' -configuration Release clean
	rm -rf build cb.plist "Couchbase Server/Couchbase Server-Info.plist"

# Couchbase Server on the Mac is distributed as a DMG file. To make a nice looking  DMG
# file with a background image and larger icons, the build needs to base it on a template.
# The template is created with the 'create-dmg' script (which you can get via
# 'brew install create-dmg'). create-dmg requires permission to run AppleScript against
# the finder, which is why we can't just run create-dmg as part of the regular build.
#
# The current background image is called "InstallerBackground.jpg".
# The current template is called "couchbase-server-macos-template_x86_64.dmg.gz"
#
# If you want to change the background or layout, modify the create-dmg options
# below and remake.

couchbase-server-macos-template_x86_64.dmg.gz: couchbase-server
	rm -rf template
	mkdir template
	cp -r build/Release/Couchbase\ Server.app template
  # copy the Couchbase app, but remove most of it, since we only need bare bones for the template
	cp ../product-texts/couchbase-server/readme/README.txt template
	rm -rf template/Couchbase\ Server.app/Contents/Frameworks/* template/Couchbase\ Server.app/Contents/Resources/couchbase-core template/Couchbase\ Server.app/Contents/Resources/*.sh
  # and of course we need a link to /Applications so they can copy the .app there
	ln -s /Applications template
  # create the DMG, at 1500MB big enough to hold everything
	create-dmg --volname "Couchbase Installer ${PRODUCT_VERSION}" \
           --background "InstallerBackground.jpg" \
	         --format UDRW \
           --window-size 800 600 \
           --icon "Couchbase Server.app" 150 200 \
           --icon "Applications" 650 200 \
           --icon "README.txt" 400 475 \
	         --disk-image-size 1500 \
           couchbase-server-macos-template_x86_64.dmg \
           template
	rm -rf template couchbase-server-macos-template_x86_64.dmg.gz
	gzip couchbase-server-macos-template_x86_64.dmg
