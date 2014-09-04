#!/bin/bash
source env.sh
#DATE_DIR=`date +%Y-%m-%d`
function create_log_dir {
    mkdir -p /tmp/ironic-xcat-test/logs/
    cd /tmp/ironic-xcat-test/logs/
    if [ -z "$ZUUL_CHANGE" ]; then
        export ZUUL_CHANGE=0
    fi
    if [ -z "$ZUUL_PIPELINE" ]; then
        export ZUUL_PIPELINE="check"
    fi
    if [ -z "$ZUUL_PATCHSET" ]; then
        export ZUUL_PATCHSET=0
    fi
    export ZUUL_LOG_DIR=${ZUUL_CHANGE}/${ZUUL_PATCHSET}/${ZUUL_PIPELINE}/${JOB_NAME}/${BUILD_NUMBER}
    mkdir -p $ZUUL_LOG_DIR
}

create_log_dir
# copy devstack setup log
scp -i /opt/ci_tmp/id_rsa -r jenkins@testcislave-tmp:/opt/stack/logs $ZUUL_LOG_DIR
cd /tmp/ironic-xcat-test/logs/$ZUUL_LOG_DIR
wget http://testcimaster:8080/job/$JOB_NAME/$BUILD_NUMBER/consoleText
mv consoleText console.log

if [[ "$ZUUL_CHANGE" != 0 ]]; then
    scp -i /opt/ci_tmp/sourceforge/id_rsa -r /tmp/ironic-xcat-test/logs/$ZUUL_CHANGE chenglch,xCAT@web.sourceforge.net:/home/frs/project/xcat/OpenStack/CI
fi