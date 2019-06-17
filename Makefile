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

couchbase-server: license readme cb.plist
	xcodebuild -target 'Couchbase Server' -configuration Release

couchbase-server-zip: license readme readme-zip cb.plist
	xcodebuild -target 'Couchbase Server Zip' -configuration Release

version_text: couchbase-server
	echo "0.0.0-0000" > build/Release/Couchbase\ Server.app/Contents/Resources/couchbase-core/VERSION.txt

cb.plist: cb.plist.tmpl
	sed 's/@SHORT_VERSION@/$(if $(PRODUCT_VERSION),$(shell echo $(PRODUCT_VERSION) | cut -d- -f1),"0.0.0")/g; s/@VERSION@/$(if $(PRODUCT_VERSION),$(PRODUCT_VERSION),"0.0.0-1000")/g' $< > $@
	cp cb.plist "Couchbase Server/Couchbase Server-Info.plist"

license:
ifeq ($(BUILD_ENTERPRISE),FALSE)
	cp ../product-texts/couchbase-server/license/ce-license.txt  makedmg/LICENSE.txt
	cp ../product-texts/couchbase-server/license/ce-license.html "Couchbase Server/Credits.html"
else
ifeq ($(BUILD_ENTERPRISE),TRUE)
	cp ../product-texts/couchbase-server/license/ee-license.txt  makedmg/LICENSE.txt
	cp ../product-texts/couchbase-server/license/ee-license.html "Couchbase Server/Credits.html"
else
	$(error "You must specify either BUILD_ENTERPRISE=FALSE or BUILD_ENTERPRISE=TRUE")
endif
endif

readme:
	cp ../product-texts/couchbase-server/readme/README.txt makedmg/README.txt

readme-zip:
	cp ../product-texts/couchbase-server/readme/README.txt makedmg/README_for_zip.txt

clean:
	(cd makedmg            && rm -f LICENSE.txt README.txt README_for_zip.txt)
	(cd "Couchbase Server" && rm -f Credits.html)
	xcodebuild -target 'Couchbase Server' -configuration Release clean
	rm -rf build cb.plist "Couchbase Server/Couchbase Server-Info.plist"
