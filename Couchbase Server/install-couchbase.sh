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

# fix the path to lib/python in the Python scripts:

_fix_python_path () {
    echo "Fixing Python lib path in $1"
    sed -i '~' -e "s,\$root/\`basename \$0\`,\"\`dirname \"\$0\"\`\/..\/lib/python\"\/\`basename \"\$0\"\`,g" $1
    rm "$1~"
}

echo "fixing path for cb* commands in `pwd`"
_fix_python_path "bin/cbadm-online-restore"
_fix_python_path "bin/cbadm-online-update"
_fix_python_path "bin/cbadm-tap-registration"
_fix_python_path "bin/cbbackup"
_fix_python_path "bin/cbbackup-incremental"
_fix_python_path "bin/cbbackup-merge-incremental"
_fix_python_path "bin/cbclusterstats"
_fix_python_path "bin/cbcollect_info"
_fix_python_path "bin/cbdbmaint"
_fix_python_path "bin/cbdbupgrade"
_fix_python_path "bin/cbepctl"
_fix_python_path "bin/cbrestore"
_fix_python_path "bin/cbstats"
_fix_python_path "bin/cbtransfer"
_fix_python_path "bin/cbvbucketctl"
_fix_python_path "bin/cbworkloadgen"
_fix_python_path "bin/collectd"
_fix_python_path "bin/collectd_memcached_buckets"
_fix_python_path "bin/couchbase-cli"
