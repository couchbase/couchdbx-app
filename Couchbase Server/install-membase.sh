#!/bin/sh -e

topdir="$PROJECT_DIR/.."

dest="$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/membase-core"

clean_lib() {
    while read something
    do
        base=${something##*/}
        echo "Fixing $1 $something -> $dest/lib/$base"
        if [ -f "$dest/lib/$base" ]
        then
            :
        else
            if [ -f "$something" ]
            then
                cp "$something" "$dest/lib/$base"
            elif [ -f "/usr/local/lib/$base" ]
            then
                cp "/usr/local/lib/$base" "$dest/lib/$base"
            else
                echo "Can't resolve $base"
                exit 1
            fi
        fi
        chmod 755 "$dest/lib/$base"
        install_name_tool -change "$something" "lib/$base" "$1"
    done
}

# ns_server bits
rsync -a "$topdir/install/" "$dest/"
rm "$dest/bin/couchjs"
cp "$PROJECT_DIR/Couchbase Server/erl" "$dest/bin/erl"
cp "$PROJECT_DIR/Couchbase Server/couchjs.tpl" "$dest/bin/couchjs.tpl"
cp "$PROJECT_DIR/Couchbase Server/erl" "$dest/lib/erlang/bin/erl"
cp "$PROJECT_DIR/Couchbase Server/start-membase.sh" "$dest/../start-server.sh"
rm "$dest/etc/membase/static_config"
cp "$topdir/ns_server/etc/static_config.in" "$dest/etc/membase/static_config.in"

mkdir -p "$dest/priv" "$dest/logs" "$dest/config" "$dest/tmp"
cp "$topdir/ns_server/priv/init.sql" \
    "$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/init.sql"

cd "$dest"

# Fun with libraries
for f in bin/* lib/couchdb/bin/*
do
    fn="$dest/$f"
    otool -L "$fn" | egrep -v "^[/a-z]" | grep -v /usr/lib \
        | grep -v /System \
        | sed -e 's/(\(.*\))//g' | clean_lib "$fn"
done

# Fun with libraries
for i in 1 2
do
    for fn in `find * -name '*.dylib'` `find * -name '*.so'`
    do
        otool -L "$fn" | egrep -v "^[/a-z]" | grep -v /usr/lib \
            | grep -v /System \
            | sed -e 's/(\(.*\))//g' | clean_lib "$fn"
    done
done
