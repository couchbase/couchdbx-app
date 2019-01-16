#!/bin/sh -e

COUCHBASE_TOP=`pwd`/couchbase-core
export COUCHBASE_TOP

PATH="$COUCHBASE_TOP:$COUCHBASE_TOP/bin":/bin:/usr/bin
export PATH

# The couchdbx-app redirects stderr to Couchbase.log under
# ~/Library/Logs, thus we echo there so that these log messages
# show up.
echo "Starting epmd ..." 1>&2
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

_check_inet_mode() {
    cmd='erl
         -pa "$COUCHBASE_TOP/lib/ns_server/erlang/lib/ns_server/ebin"
         -noshell
         -setcookie nocookie
         -run dist_manager get_proto_dist_type "$datadir/var/lib/couchbase" start'
    eval PROTO_DIST=\$\($cmd\)

    if [ $? -ne 0 ]
    then
        echo $PROTO_DIST
        exit 1
    fi

    if [ $PROTO_DIST == "inet6_tcp" ]; then
        VM_NAME='babysitter_of_ns_1@::1'
        IPV6=true
    else
        VM_NAME='babysitter_of_ns_1@127.0.0.1'
        IPV6=false
    fi
}

datadir="$HOME/Library/Application Support/Couchbase"

_check_data_is_good() {
    config="${datadir}"/var/lib/couchbase/config
    if [ -d "${config}" ]
    then
        # Run cbupgrade with the namespace_upgrade_only flag, which was added
        # specifically for this script and will ensure any database files are
        # compatible with KV-engine and is effectively a no-op if they already
        # are.
        if ! sh "${COUCHBASE_TOP}"/bin/cbupgrade \
              -c "${config}" \
              -a yes \
              --namespace_upgrade_only
        then
            echo "Error: exit of $? from cbupgrade"
            exit 1
        fi
    fi
}

DEFAULT_CONFIG_DIR="$COUCHBASE_TOP/etc/couchdb/default.d"
DEFAULT_CONFIG_FILE="$COUCHBASE_TOP/etc/couchdb/default.ini"
LOCAL_CONFIG_DIR="$COUCHBASE_TOP/etc/couchdb/local.d"
LOCAL_CONFIG_FILE="$COUCHBASE_TOP/etc/couchdb/local.ini"
PLATFORM_CONFIG_FILE="$datadir/etc/couch-platform.ini"
CUSTOM_CONFIG_FILE="$datadir/etc/couch-custom.ini"
STATIC_CONFIG_FILE=$(printf %q "$datadir/etc/couchbase/static_config")

mkdir -p "$DEFAULT_CONFIG_DIR" "$LOCAL_CONFIG_DIR" "$datadir/etc"

couchname=`basename "$COUCHBASE_TOP/lib/couchdb/erlang/lib/"couch-*/`

sed -e "s,@APP_PATH@,$COUCHBASE_TOP,g" -e "s,@DATADIR@,$datadir,g" \
    -e "s,@HOME@,$HOME,g" -e "s,@COUCHNAME@,$couchname,g" <<EOF > "$PLATFORM_CONFIG_FILE"
[couchdb]
database_dir = @DATADIR@/var/lib/couchbase/data
view_index_dir = @DATADIR@/var/lib/couchbase/data
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
_check_inet_mode
_check_data_is_good

echo "Starting Couchbase Server ..." 1>&2
# Run Erlang. This will run until the app stops the server by sending a quit command to stdin.
eval erl \
    +A 16 \
    -kernel inet_dist_listen_min 21100 inet_dist_listen_max 21299 \
    -sasl sasl_error_logger false \
    -hidden \
    -name $VM_NAME \
    -proto_dist $PROTO_DIST \
    -setcookie nocookie \
    $* \
    -run ns_babysitter_bootstrap -- \
    -couch_ini $couch_start_arguments \
    -ns_babysitter cookiefile "\"\\\"$COOKIEFILE\\\"\"" \
    -ns_server config_path "\"\\\"$datadir/etc/couchbase/static_config\\\"\"" \
    -ns_server pidfile "\"\\\"$datadir/couchbase-server.pid\\\"\"" \
    -ns_server cookiefile "\"\\\"$COOKIEFILE-ns-server\\\"\"" \
    -ns_server dont_suppress_stderr_logger true \
    -ns_server loglevel_stderr info \
    -ns_server ipv6 $IPV6


echo "Couchbase Server has stopped." 1>&2

# The couchdbx-app shuts down Couchbase Server by invoking q() (aka init:stop())
# on it - which shuts down the babysitter gracefully. However it can take a
# brief moment for the Erlang sub-processes (such as the CouchDB VM) to disconnect
# from epmd. Waiting briefly allows us to actually stop epmd in almost all cases.
# To be certain of stopping epmd we'd have to run `epmd -names` and wait until it
# returned a list of names of VMs that are not Couchbase related. However, this is
# complicated and brittle and seems like overkill. So, we just sleep. In the worst
# case the user will have to manually kill epmd.
sleep 1

echo "Stopping epmd ..." 1>&2
# On exit, stop the epmd process we started (if no one else is using it)
epmd -kill
