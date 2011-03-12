#!/bin/sh -e

instdir=${SRCROOT%dependencies/couchdbx-app}
builddir=${instdir}build/

dest=$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/couchdbx-core

clean_lib() {
    while read something
    do
        install_name_tool -change $instdir$something $something $1
        install_name_tool -change $builddir$something $something $1
    done
}

# Find and cleanup all libs.
for l in $dest/lib/*.dylib $dest/lib/couchdb/bin/couchjs \
    $dest/lib/couchdb/erlang/lib/couch-*/priv/lib/couch_icu_driver.so
do
    otool -L $l | grep "$instdir" \
        | sed -e 's/(\(.*\))//g' -e "s,${instdir}build/,," | clean_lib $l
done

absolutize() {
        # change absolute paths to dynamic absolute paths
        echo absolutifying $1
        perl -pi -e "s@$builddir@\`pwd\`/@" $dest/$1
}

relativize() {
        # change absolute paths to dynamic absolute paths
        echo relativizing $1
        perl -pi -e "s@$builddir@@" $dest/$1
}

for f in bin/erl bin/js-config bin/icu-config bin/couchdb bin/couchjs
do
    absolutize $f
done

relativize etc/couchdb/default.ini
