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
    export ZUUL_LOG_DIR=${JOB_NAME}_${BUILD_NUMBER}
    mkdir $ZUUL_LOG_DIR
    scp -i /opt/ci_tmp/id_rsa jenkins@9.114.34.161:/opt/stack/logs.tar.gz $ZUUL_LOG_DIR
}

job_log
cd /tmp/ironic-xcat-test/logs/$DATE_DIR/$ZUUL_LOG_DIR
tar xvfz logs.tar.gz
$console_result=`ls consoleTest*`
if [[ -n "$console_result" ]]; then
    rm consoleText*
fi

wget http://9.114.34.160:8080/job/$JOB_NAME/$BUILD_NUMBER/consoleText
mv consoleText "console_$JOB_NAME_$BUILD_NUMBER.log"
