PRODUCT_VERSION := $(shell git describe)

all: couchbase-server

couchbase-server: cb.plist
	xcodebuild -target 'Couchbase Server' -configuration Release

couchbase-server-zip: cb.plist
	xcodebuild -target 'Couchbase Server Zip' -configuration Release

cb.plist: cb.plist.tmpl
	sed s/@VERSION@/$(PRODUCT_VERSION)/g $< > $@
	cp cb.plist "Couchbase Server/Couchbase Server-Info.plist"

clean:
	xcodebuild -target 'Couchbase Server' -configuration Release clean
	rm -rf build cb.plist "Couchbase Server/Couchbase Server-Info.plist"
