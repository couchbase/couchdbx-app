#
# To make the couchbase server app bundle, use:
#   make couchbase-server-zip LICENSE=LICENSE-enterprise.txt
#
# If you just want to quickly make the Couchbase Server.app file, do:
#   make couchbase-server LICENSE=LICENSE-enterprise.txt
#
# The .app file will be created in couchdbx-app/build/Release
# 

all: couchbase-server

couchbase-server: license cb.plist
	xcodebuild -target 'Couchbase Server' -configuration Release

couchbase-server-zip: license cb.plist
	xcodebuild -target 'Couchbase Server Zip' -configuration Release

cb.plist: cb.plist.tmpl
	sed 's/@SHORT_VERSION@/$(if $(PRODUCT_VERSION),$(shell echo $(PRODUCT_VERSION) | cut -d- -f1),"0.0.0")/g; s/@VERSION@/$(if $(PRODUCT_VERSION),$(PRODUCT_VERSION),"0.0.0-1000")/g' $< > $@
	cp cb.plist "Couchbase Server/Couchbase Server-Info.plist"

license:
ifeq ($(if $(LICENSE),$(LICENSE),LICENSE-community.txt),LICENSE-community.txt)
	(cd makedmg            && cp LICENSE.community.txt  LICENSE.txt)
	(cd "Couchbase Server" && cp Credits.community.html Credits.html)
else
ifeq ($(LICENSE),LICENSE-enterprise.txt)
	(cd makedmg            && cp LICENSE.enterprise.txt  LICENSE.txt)
	(cd "Couchbase Server" && cp Credits.enterprise.html Credits.html)
else
	$(error "You must specify either LICENSE=LICENSE-enterprise.txt or LICENSE=LICENSE-community.txt")
endif
endif

clean:
	(cd makedmg            && rm -f LICENSE.txt)
	(cd "Couchbase Server" && rm -f Credits.html)
	xcodebuild -target 'Couchbase Server' -configuration Release clean
	rm -rf build cb.plist "Couchbase Server/Couchbase Server-Info.plist"
