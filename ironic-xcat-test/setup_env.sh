#!/bin/bash

virsh snapshot-revert test_ci_slave_temp test_ci_slave_temp.scp
virsh start test_ci_slave_temp
bash rmlog.sh
sleep 30s

echo "#!/bin/bash" > env.sh
if [ -n "$ZUUL_PROJECT" ]; then
    echo "export ZUUL_PROJECT=$ZUUL_PROJECT" >> env.sh
fi

if [ -n "$ZUUL_BRANCH" ]; then
    echo "export ZUUL_BRANCH=$ZUUL_BRANCH" >> env.sh
fi

if [ -n "$ZUUL_REF" ]; then
    echo "export ZUUL_REF=$ZUUL_REF" >> env.sh
fi

if [ -z "$ZUUL_CHANGE" ]; then
    ZUUL_CHANGE=0
fi
echo "export ZUUL_CHANGE=$ZUUL_CHANGE" >> env.sh

if [ -n "$ZUUL_PATCHSET" ]; then
    echo "export ZUUL_PATCHSET=$ZUUL_PATCHSET" >> env.sh
fi

if [ -z "$ZUUL_PIPELINE" ]; then
    ZUUL_PIPELINE="check"
fi
echo "export ZUUL_PIPELINE=$ZUUL_PIPELINE" >> env.sh

if [ -n "$JOB_NAME" ]; then
    echo "export JOB_NAME=$JOB_NAME" >> env.sh
fi

if [ -n "$BUILD_NUMBER" ]; then
    echo "export BUILD_NUMBER=$BUILD_NUMBER" >> env.sh
fi

if [ -n "$GERRIT_CHANGE_NUMBER" ]; then
    echo "export GERRIT_CHANGE_NUMBER=$GERRIT_CHANGE_NUMBER" >> env.sh
fi

if [ -n "$GERRIT_PATCHSET_NUMBER" ]; then
    echo "export GERRIT_PATCHSET_NUMBER=$GERRIT_PATCHSET_NUMBER" >> env.sh
fi

if [ -n "$BRANCH_OVERRIDE" ]; then
    echo "export BRANCH_OVERRIDE=$BRANCH_OVERRIDE" >> env.sh
    if [ "$BRANCH_OVERRIDE" != "default" ] ; then
        echo "export OVERRIDE_ZUUL_BRANCH=$BRANCH_OVERRIDE" >> env.sh
    fi
fi

echo "export JENKINS_JOB_WORKSPACE=$WORKSPACE" >> env.sh

chmod 755 env.sh
source env.sh
function create_log_dir {
    cd $WORKSPACE
    rm -rf *
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
export JENKINS_LOG_WORKSPACE=${JENKINS_JOB_WORKSPACE}/${ZUUL_LOG_DIR}
cd /opt/ci_tmp
echo "export JENKINS_LOG_WORKSPACE=$JENKINS_LOG_WORKSPACE" >> env.sh
scp -i /opt/ci_tmp/id_rsa ./env.sh jenkins@testcislave-tmp:~/