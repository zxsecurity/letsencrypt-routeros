#!/usr/bin/env bash

#
# Deploy certificates to all network devices
#

set -e
set -u
set -o pipefail
umask 077

done="no"

if [[ "$1" = "deploy_cert" ]]; then
        ./letsencrypt-routeros.sh
        done="yes"
fi

if [[ "${1}" =~ ^(deploy_challenge|clean_challenge|sync_cert|deploy_ocsp|unchanged_cert|invalid_challenge|request_failure|generate_csr|startup_hook|exit_hook)$ ]]; then
        # do nothing for now
        done="yes"
fi

if [[ "${1}" = "this_hookscript_is_broken__dehydrated_is_working_fine__please_ignore_unknown_hooks_in_your_script" ]]; then
        # do nothing
        done="yes"
fi

if [[ ! "${done}" = "yes" ]]; then
    echo Unkown hook "${1}"
    exit 1
fi

exit 0