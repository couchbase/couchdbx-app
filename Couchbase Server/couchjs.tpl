#! /bin/sh -e

# Copyright 2011 Couchbase, Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

SCRIPT_OK=0
SCRIPT_ERROR=1

DEFAULT_VERSION=170

basename=${0##*/}

display_version () {
    cat << EOF
$basename - Apache CouchDB 1.2.0a-686d194-git

Licensed under the Apache License, Version 2.0 (the "License"); you may not use
this file except in compliance with the License. You may obtain a copy of the
License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.
EOF
}

display_help () {
    cat << EOF
Usage: $basename [FILE]

The $basename command runs the Apache CouchDB JavaScript interpreter.

The exit status is 0 for success or 1 for failure.

Options:

  -h  display a short help message and exit
  -V  display version information and exit
  -H  install couchjs cURL bindings (only avaiable
      if CouchDB was built with cURL available)

Report bugs at <https://issues.apache.org/jira/browse/COUCHDB>.
EOF
}

display_error () {
    if test -n "$1"; then
        echo $1 >&2
    fi
    echo >&2
    echo "Try \`"$basename" -h' for more information." >&2
    exit $SCRIPT_ERROR
}

run_couchjs () {
    exec "@APP_DIR@/lib/couchdb/bin/couchjs" "$@"
}

parse_script_option_list () {
    set +e
    options=`getopt hVH $@`
    if test ! $? -eq 0; then
        display_error
    fi
    set -e
    eval set -- $options
    while [ $# -gt 0 ]; do
        case "$1" in
            -h) shift; display_help; exit $SCRIPT_OK;;
            -V) shift; display_version; exit $SCRIPT_OK;;
            --) shift; break;;
            *) break;;
        esac
    done
    script_name=`echo "$@" | sed -e 's/.*--[[:blank:]]*//'`
    if test -z "$script_name"; then
        display_error "You must specify a FILE."
    fi
    options=`echo "$@" | sed -e 's/--//'`
    run_couchjs "$options"
}

parse_script_option_list $@
