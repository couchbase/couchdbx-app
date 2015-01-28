all: couchbase-server

couchbase-server: license cb.plist
	xcodebuild -target 'Couchbase Server' -configuration Release

couchbase-server-zip: license cb.plist
	xcodebuild -target 'Couchbase Server Zip' -configuration Release

cb.plist: cb.plist.tmpl
	sed s/@VERSION@/$(PRODUCT_VERSION)/g $< > $@
	cp cb.plist "Couchbase Server/Couchbase Server-Info.plist"

license:
ifeq ($(LICENSE),LICENSE-community.txt)
	(cd makedmg            && cp LICENSE.community.txt  LICENSE.txt)
	(cd "Couchbase Server" && cp Credits.community.html Credits.html)
endif
ifeq ($(LICENSE),LICENSE-enterprise.txt)
	(cd makedmg            && cp LICENSE.enterprise.txt  LICENSE.txt)
	(cd "Couchbase Server" && cp Credits.enterprise.html Credits.html)
endif

clean:
	(cd makedmg            && rm -f LICENSE.txt)
	(cd "Couchbase Server" && rm -f Credits.html)
	xcodebuild -target 'Couchbase Server' -configuration Release clean
	rm -rf build cb.plist "Couchbase Server/Couchbase Server-Info.plist"
