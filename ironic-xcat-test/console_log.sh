#!/bin/bash
source env.sh
DATE_DIR=`date +%Y-%m-%d`
function job_log {
    mkdir -p /tmp/ironic-xcat-test/logs/$DATE_DIR
    cd /tmp/ironic-xcat-test/logs/$DATE_DIR
    if [ -z "$ZUUL_CHANGE" ]; then
        export ZUUL_CHANGE=0
    fi
    if [ -z "$ZUUL_PIPELINE" ]; then
        export ZUUL_PIPELINE="check"
    fi
    export ZUUL_LOG_DIR=zuul_${ZUUL_CHANGE}_${JOB_NAME}_${BUILD_NUMBER}
    mkdir $ZUUL_LOG_DIR
    scp -i /opt/ci_tmp/id_rsa -r jenkins@testcislave-tmp:/opt/stack/logs $ZUUL_LOG_DIR
}

job_log
cd /tmp/ironic-xcat-test/logs/$DATE_DIR/$ZUUL_LOG_DIR


wget http://testcimaster:8080/job/$JOB_NAME/$BUILD_NUMBER/consoleText
mv consoleText "console_${JOB_NAME}_${BUILD_NUMBER}.log"
scp -i /opt/ci_tmp/sourceforge/id_rsa -r /tmp/ironic-xcat-test/logs/$DATE_DIR chenglch,xCAT@web.sourceforge.net:/home/frs/project/xcat/OpenStack/CI

#ssh chenglch,xCAT@web.sourceforge.net mkdir -p /home/frs/project/xcat/OpenStack/CI/$DATE_DIR

#scp -i /opt/ci_tmp/id_rsa -r 2014-08-31 jenkins@9.114.34.161:/tmp
#scp -i /opt/ci_tmp/id_rsa -r jenkins@9.114.34.161:/opt/stack/logs /tmp