#!/bin/sh -e

instdir=${SRCROOT%dependencies/couchdbx-app}
builddir="${instdir}build/"

dest="$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/couchdbx-core"

clean_lib() {
    echo "Cleaning $1"
    while read something
    do
        base=${something##*/}
        echo "  Fixing $something -> lib/$base"
        test -f "$dest/lib/$base" || cp "$something" "$dest/lib/$base"
        chmod 755 "$dest/lib/$base"
        install_name_tool -change "$something" "lib/$base" "$1"
    done
}

# The wrong mozjs is installed.  We require homebrew's spidermonkey to
# build, and we link against it, but we've built our own.  This is a
# kind of ugly build hack, but it's why we test.
rm "$dest/lib/libmozjs.dylib"

# Find and cleanup all libs.
# Do this twice so it picks up libs that got pulled in.
for i in 1 2 3
do
    for fn in "$dest/lib/"*.dylib "$dest/lib/couchdb/bin/couchjs" \
	"$dest/lib/couchdb/erlang/lib/"couch-*/priv/lib/couch_icu_driver.so
    do
	otool -L "$fn" | egrep -v "^[/a-z]" | grep -v /usr/lib \
            | sed -e 's/(\(.*\))//g' | clean_lib "$fn"
    done
done

absolutize() {
        # change absolute paths to dynamic absolute paths
        echo absolutifying $1
        perl -pi -e "s@$builddir@\`pwd\`/@" "$dest/$1"
}

relativize() {
        # change absolute paths to dynamic absolute paths
        echo relativizing $1
        perl -pi -e "s@$builddir@@" "$dest/$1"
}

for f in bin/erl bin/js-config bin/icu-config bin/couchdb bin/couchjs
do
    absolutize $f
done

relativize etc/couchdb/default.ini

# Clean up unnecessary items

cd "$dest/lib/erlang/lib"
rm -rf \
    appmon-*/ \
    asn1-*/ \
    common_test-*/ \
    compiler-*/ \
    cosEvent-*/ \
    cosEventDomain-*/ \
    cosFileTransfer-*/ \
    cosNotification-*/ \
    cosProperty-*/ \
    cosTime-*/ \
    cosTransactions-*/ \
    debugger-*/ \
    dialyzer-*/ \
    docbuilder-*/ \
    edoc-*/ \
    erl_docgen-*/ \
    erl_interface-*/ \
    erts-*/ \
    et-*/ \
    eunit-*/ \
    gs-*/ \
    hipe-*/ \
    ic-*/ \
    inviso-*/ \
    jinterface-*/ \
    megaco-*/ \
    mnesia-*/ \
    observer-*/ \
    odbc-*/ \
    orber-*/ \
    os_mon-*/ \
    otp_mibs-*/ \
    parsetools-*/ \
    percept-*/ \
    pman-*/ \
    reltool-*/ \
    runtime_tools-*/ \
    snmp-*/ \
    ssh-*/ \
    syntax_tools-*/ \
    test_server-*/ \
    toolbar-*/ \
    tools-*/ \
    tv-*/ \
    typer-*/ \
    webtool-*/ \
    wx-*/

rm -rf */{examples,src,include} */priv/obj

cd "$dest"
rm -rf lib/erlang/erts-*/include
rm -rf etc/logrotate.d include info man \
    share/autoconf share/doc share/icu share/emacs share/man \
    lib/*.a lib/icu lib/erlang/usr 
