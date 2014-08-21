#!/bin/bash

function clean_netns {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local ns=`ip netns list | xargs`
    for n in $ns; do
        ip netns delete $n
    done
    $xtrace
}

sudo -H -u stack bash $BASE/new/devstack/unstack.sh
sudo -H -u stack pkill -ustack
clean_netns
