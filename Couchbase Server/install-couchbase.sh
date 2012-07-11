#!/bin/sh -e

topdir="$PROJECT_DIR/.."

dest="$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/couchbase-core"

# ns_server bits
rsync -a --delete "$topdir/install/" "$dest/"
rm "$dest/bin/couchjs"
cp "$PROJECT_DIR/Couchbase Server/erl" "$dest/bin/erl"
cp "$PROJECT_DIR/Couchbase Server/couchjs.tpl" "$dest/bin/couchjs.tpl"
cp "$PROJECT_DIR/Couchbase Server/erl" "$dest/lib/erlang/bin/erl"
cp "$PROJECT_DIR/Couchbase Server/start-couchbase.sh" "$dest/../start-server.sh"
rm "$dest/etc/couchbase/static_config"
cp "$topdir/ns_server/etc/static_config.in" "$dest/etc/couchbase/static_config.in"

mkdir -p "$dest/priv" "$dest/logs" "$dest/config" "$dest/tmp"
cp "$topdir/ns_server/priv/init.sql" \
    "$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/init.sql"

echo "Installing and fixing up libraries:"
cd "$dest"
ruby "$PROJECT_DIR/Couchbase Server/install_libraries.rb"

cd "$topdir/install"
install_absolute_path=`pwd`

cd "$dest"
# fix cli paths
echo "fixing path for cb* commands in `pwd`"
sed -ie "s,\$root/\`basename \$0\`,\"\`dirname \"\$0\"\`\/..\/lib/python\"\/\`basename \"\$0\"\`,g" bin/couchbase-cli
sed -ie "s,\$root/\`basename \$0\`,\"\`dirname \"\$0\"\`\/..\/lib/python\"\/\`basename \"\$0\"\`,g" bin/cbstats
sed -ie "s,\$root/\`basename \$0\`,\"\`dirname \"\$0\"\`\/..\/lib/python\"\/\`basename \"\$0\"\`,g" bin/cbadm-online-restore
sed -ie "s,\$root/\`basename \$0\`,\"\`dirname \"\$0\"\`\/..\/lib/python\"\/\`basename \"\$0\"\`,g" bin/cbadm-online-update
sed -ie "s,\$root/\`basename \$0\`,\"\`dirname \"\$0\"\`\/..\/lib/python\"\/\`basename \"\$0\"\`,g" bin/cbadm-tap-registration
sed -ie "s,\$root/\`basename \$0\`,\"\`dirname \"\$0\"\`\/..\/lib/python\"\/\`basename \"\$0\"\`,g" bin/cbbackup
sed -ie "s,\$root/\`basename \$0\`,\"\`dirname \"\$0\"\`\/..\/lib/python\"\/\`basename \"\$0\"\`,g" bin/cbbackup-incremental
sed -ie "s,\$root/\`basename \$0\`,\"\`dirname \"\$0\"\`\/..\/lib/python\"\/\`basename \"\$0\"\`,g" bin/cbbackup-merge-incremental
sed -ie "s,\$root/\`basename \$0\`,\"\`dirname \"\$0\"\`\/..\/lib/python\"\/\`basename \"\$0\"\`,g" bin/cbdbmaint
sed -ie "s,\$root/\`basename \$0\`,\"\`dirname \"\$0\"\`\/..\/lib/python\"\/\`basename \"\$0\"\`,g" bin/cbdbupgrade
sed -ie "s,\$root/\`basename \$0\`,\"\`dirname \"\$0\"\`\/..\/lib/python\"\/\`basename \"\$0\"\`,g" bin/cbrestore
sed -ie "s,\$root/\`basename \$0\`,\"\`dirname \"\$0\"\`\/..\/lib/python\"\/\`basename \"\$0\"\`,g" bin/cbworkloadgen
