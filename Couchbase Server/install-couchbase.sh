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

echo "Installing and fixing up libraries:"
cd "$dest"
ruby "$PROJECT_DIR/Couchbase Server/install_libraries.rb"

cd "$topdir/install"
install_absolute_path=`pwd`

cd "$dest"

# fix the path to lib/python in the Python scripts:

_fix_python_path () {
    echo "Fixing Python lib path in $1"
    sed -i '~' -e "s,\/opt\/couchbase,\`dirname \"\$0\"\`\/$2,g" $1
    rm "$1~"
}

echo "fixing path for cb* commands in `pwd`"
_fix_python_path "bin/cbbackup"                 ".."
_fix_python_path "bin/cbcollect_info"           ".."
_fix_python_path "bin/cbepctl"                  ".."
_fix_python_path "bin/cbrestore"                ".."
_fix_python_path "bin/cbstats"                  ".."
_fix_python_path "bin/cbvbucketctl"             ".."
_fix_python_path "bin/couchbase-cli"            ".."

_fix_python_path "bin/tools/cbanalyze-core"                         "../.."
_fix_python_path "bin/tools/cbclusterstats"                         "../.."
_fix_python_path "bin/tools/cbdocloader"                            "../.."
_fix_python_path "bin/tools/cbtransfer"                             "../.."
_fix_python_path "bin/tools/cbworkloadgen"                          "../.."

_fix_python_path "bin/tools/unsupported/collectd"                   "../../.."
_fix_python_path "bin/tools/unsupported/collectd_memcached_buckets" "../../.."
