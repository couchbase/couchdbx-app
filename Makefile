VERSION=`git describe`

all: cb.plist
	xcodebuild

cb.plist: cb.plist.tmpl
	sed s/@VERSION@/$(VERSION)/g $< > $@
	cp cb.plist "Couchbase Server/Couchbase Server-Info.plist"

clean:
	rm -rf build cb.plist "Couchbase Server/Couchbase Server-Info.plist"
