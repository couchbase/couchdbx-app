#!/bin/sh -e

# was:  sed -i '~' -e "s,\/opt\/couchbase,\`dirname \"\$0\"\`\/$2,g" $1
#
# need to escape SPACES in directory name !

echo        running $0
THIS_DIR=`dirname "\$0"`
INST_DIR=${THIS_DIR}
echo installing to ${INST_DIR}

topdir="$PROJECT_DIR/.."

dest="$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/couchbase-core"

# ns_server bits
rsync -a --delete "$topdir/install/" "$dest/"
rm -f "$dest/bin/couchjs"
cp "$PROJECT_DIR/Couchbase Server/erl"                "$dest/bin/erl"
cp "$PROJECT_DIR/Couchbase Server/couchjs.tpl"        "$dest/bin/couchjs.tpl"
cp "$PROJECT_DIR/Couchbase Server/erl"                "$dest/lib/erlang/bin/erl"
cp "$PROJECT_DIR/Couchbase Server/start-couchbase.sh" "$dest/../start-server.sh"
rm "$dest/etc/couchbase/static_config"
cp "$topdir/ns_server/etc/static_config.in"           "$dest/etc/couchbase/static_config.in"
rm "$dest/etc/couchbase/serverless_profile"
cp "$topdir/ns_server/etc/serverless_profile"           "$dest/etc/couchbase/serverless_profile"
rm -f "$dest/etc/couchbase/ssl_dist_opts"
cp "$topdir/ns_server/etc/ssl_dist_opts.in"           "$dest/etc/couchbase/ssl_dist_opts.in"
cp "$topdir/ns_server/etc/hosts.cfg"                  "$dest/etc/couchbase/hosts.cfg"

mkdir -p "$dest/priv" "$dest/logs" "$dest/config" "$dest/tmp"

chmod -R g-w "$dest"

cd "$topdir/install"
install_absolute_path=`pwd`

cd "$dest"
