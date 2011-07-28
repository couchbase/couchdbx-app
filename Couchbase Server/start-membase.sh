#!/bin/sh -e

MEMBASE_TOP=`pwd`/membase-core
export MEMBASE_TOP

DYLD_LIBRARY_PATH="$MEMBASE_TOP:$MEMBASE_TOP/lib"
export DYLD_LIBRARY_PATH

echo DYLD_LIBRARY_PATH is "$DYLD_LIBRARY_PATH"

PATH="$MEMBASE_TOP:$MEMBASE_TOP/bin":/bin:/usr/bin
export PATH

erl -noshell -setcookie nocookie -sname init -run init stop 2>&1 > /dev/null
if [ $? -ne 0 ]
then
    exit 1
fi

couch_start_arguments=""

_add_config_file () {
    couch_start_arguments="$couch_start_arguments '$1'"
}

_add_config_dir () {
    for file in "$1"/*.ini; do
        if [ -r "$file" ]; then
          _add_config_file "$file"
        fi
    done
}

_load_config () {
    _add_config_file "$DEFAULT_CONFIG_FILE"
    _add_config_dir "$DEFAULT_CONFIG_DIR"
    _add_config_file "$LOCAL_CONFIG_FILE"
    _add_config_dir "$LOCAL_CONFIG_DIR"
    if [ "$COUCHDB_ADDITIONAL_CONFIG_FILE" != '' ]
    then
        _add_config_file "$COUCHDB_ADDITIONAL_CONFIG_FILE"
    fi
}

datadir="$HOME/Library/Application Support/Membase"

DEFAULT_CONFIG_DIR="$MEMBASE_TOP/etc/couchdb/default.d"
DEFAULT_CONFIG_FILE="$MEMBASE_TOP/etc/couchdb/default.ini"
LOCAL_CONFIG_DIR="$MEMBASE_TOP/etc/couchdb/local.d"
LOCAL_CONFIG_FILE="$MEMBASE_TOP/etc/couchdb/local.ini"
PLATFORM_CONFIG_FILE="$datadir/etc/couch-platform.ini"
CUSTOM_CONFIG_FILE="$datadir/etc/couch-custom.ini"

mkdir -p "$DEFAULT_CONFIG_DIR" "$LOCAL_CONFIG_DIR" "$datadir/etc"

couchname=`basename "$MEMBASE_TOP/lib/couchdb/erlang/lib/"couch*/`

sed -e "s,@APP_PATH@,$MEMBASE_TOP,g" -e "s,@DATADIR@,$datadir,g" \
    -e "s,@HOME@,$HOME,g" -e "s,@COUCHNAME@,$couchname,g" <<EOF > "$PLATFORM_CONFIG_FILE"
[couchdb]
database_dir = @DATADIR@/var/lib/couchdb
view_index_dir = @DATADIR@/var/lib/couchdb
util_driver_dir = @APP_PATH@/lib/couchdb/erlang/lib/@COUCHNAME@/priv/lib
uri_file = @DATADIR@/var/couch.uri

[query_servers]
javascript = "@APP_PATH@/bin/couchjs" "@APP_PATH@/share/couchdb/server/main.js"
coffeescript = "@APP_PATH@/bin/couchjs" "@APP_PATH@/share/couchdb/server/main-coffee.js"

[log]
file = @HOME@/Library/Logs/couchbase-server.log
EOF

touch "$CUSTOM_CONFIG_FILE"

sed "s,@APP_DIR@,$MEMBASE_TOP,g" < "$MEMBASE_TOP/bin/couchjs.tpl" > "$MEMBASE_TOP/bin/couchjs"

mkdir -p "$datadir/var/lib/membase/logs"
cd "$datadir"

ERL_LIBS="$MEMBASE_TOP/lib/couchdb/erlang/lib:$MEMBASE_TOP/lib/ns_server/erlang/lib:$MEMBASE_TOP/lib/couchdb/plugins"
export ERL_LIBS

mkdir -p "$datadir/etc/membase"

sed -e "s|@DATA_PREFIX@|$datadir|g" -e "s|@BIN_PREFIX@|$MEMBASE_TOP|g" \
    "$MEMBASE_TOP/etc/membase/static_config.in" > "$datadir/etc/membase/static_config"

_load_config
_add_config_file "$PLATFORM_CONFIG_FILE"
_add_config_file "$CUSTOM_CONFIG_FILE"

eval exec erl \
    +A 16 \
    -setcookie nocookie \
    -kernel inet_dist_listen_min 21100 inet_dist_listen_max 21299 \
    $* \
    -run ns_bootstrap -- \
    -couch_ini $couch_start_arguments \
    -ns_server config_path "\"\\\"$datadir/etc/membase/static_config\\\"\"" \
    -ns_server pidfile "\"\\\"$datadir/membase-server.pid\\\"\"" \
    -ns_server dont_suppress_stderr_logger true
