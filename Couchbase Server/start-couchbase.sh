#!/bin/sh -e

COUCHBASE_TOP=`pwd`/couchbase-core
export COUCHBASE_TOP

DYLD_LIBRARY_PATH="$COUCHBASE_TOP:$COUCHBASE_TOP/lib"
export DYLD_LIBRARY_PATH

echo DYLD_LIBRARY_PATH is "$DYLD_LIBRARY_PATH"

PATH="$COUCHBASE_TOP:$COUCHBASE_TOP/bin":/bin:/usr/bin
export PATH

epmd -daemon

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

datadir="$HOME/Library/Application Support/Couchbase"

DEFAULT_CONFIG_DIR="$COUCHBASE_TOP/etc/couchdb/default.d"
DEFAULT_CONFIG_FILE="$COUCHBASE_TOP/etc/couchdb/default.ini"
LOCAL_CONFIG_DIR="$COUCHBASE_TOP/etc/couchdb/local.d"
LOCAL_CONFIG_FILE="$COUCHBASE_TOP/etc/couchdb/local.ini"
PLATFORM_CONFIG_FILE="$datadir/etc/couch-platform.ini"
CUSTOM_CONFIG_FILE="$datadir/etc/couch-custom.ini"

mkdir -p "$DEFAULT_CONFIG_DIR" "$LOCAL_CONFIG_DIR" "$datadir/etc"

couchname=`basename "$COUCHBASE_TOP/lib/couchdb/erlang/lib/"couch-*/`

sed -e "s,@APP_PATH@,$COUCHBASE_TOP,g" -e "s,@DATADIR@,$datadir,g" \
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

[access_log]
enable = false
format = extended
file = @HOME@/Library/Logs/couch_access.log
EOF

touch "$CUSTOM_CONFIG_FILE"
touch "$HOME/Library/Preferences/couchbase-server.ini"

sed "s,@APP_DIR@,$COUCHBASE_TOP,g" < "$COUCHBASE_TOP/bin/couchjs.tpl" > "$COUCHBASE_TOP/bin/couchjs"
chmod 755 "$COUCHBASE_TOP/bin/couchjs"

mkdir -p "$datadir/var/lib/couchbase/logs"
cd "$datadir"

COOKIEFILE="$datadir/var/lib/couchbase/couchbase-server.cookie"

#This order is important - ravi
ERL_LIBS="$COUCHBASE_TOP/lib/ns_server/erlang/lib:$COUCHBASE_TOP/lib/couchdb/erlang/lib:$COUCHBASE_TOP/lib/couchdb/plugins"
export ERL_LIBS

umask 007
ERL_MAX_PORTS=1024
export ERL_MAX_PORTS


# Limit number of vbuckets to avoid running out of file descriptors; attempts to raise the
# RLIMIT_NOFILE in the AppDelegate code have been unsuccessful.
COUCHBASE_NUM_VBUCKETS=64
export COUCHBASE_NUM_VBUCKETS

mkdir -p "$datadir/etc/couchbase"

sed -e "s|@DATA_PREFIX@|$datadir|g" -e "s|@BIN_PREFIX@|$COUCHBASE_TOP|g" \
    "$COUCHBASE_TOP/etc/couchbase/static_config.in" > "$datadir/etc/couchbase/static_config"

_load_config
_add_config_file "$PLATFORM_CONFIG_FILE"
_add_config_file "$CUSTOM_CONFIG_FILE"

# Run Erlang. This will run until the app stops the server by sending a quit command to stdin.
eval erl \
    +A 16 \
    -kernel inet_dist_listen_min 21100 inet_dist_listen_max 21299 \
    -hidden \
    -name 'babysitter_of_ns_1@127.0.0.1' \
    -setcookie nocookie \
    $* \
    -eval 'os:putenv("ERL_MAX_PORTS","").' \
    -run ns_babysitter_bootstrap -- \
    -couch_ini $couch_start_arguments \
    -ns_babysitter cookiefile "\"$COOKIEFILE\"" \
    -ns_server config_path "\"\\\"$datadir/etc/couchbase/static_config\\\"\"" \
    -ns_server pidfile "\"\\\"$datadir/couchbase-server.pid\\\"\"" \
    -ns_server cookiefile "\"$COOKIEFILE-ns-server\"" \
    -ns_server dont_suppress_stderr_logger true


# On exit, stop the epmd process we started (if no one else is using it)
epmd -kill
