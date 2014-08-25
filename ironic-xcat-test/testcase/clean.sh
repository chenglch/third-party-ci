#!/bin/bash
CUR_DIR=`pwd`
source ${CUR_DIR}/config.sh
function clean_netns {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local ns=`ip netns list | xargs`
    for n in $ns; do
        sudo ip netns delete $n
    done
    $xtrace
}

sudo -H -u stack bash $BASE/new/devstack/unstack.sh
clean_netns
sudo rm -rf $BASE/new/ironic
pkill -ustack

