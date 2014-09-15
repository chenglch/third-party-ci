#!/bin/bash
source env.sh
export BASE=/opt/stack
source $BASE/ironic-xcat-test/testcase/config.sh
set -o xtrace
if [ -z $ZUUL_PROJECT ]; then
    export ZUUL_PROJECT=openstack-dev/sandbox
fi
if [ -z $ZUUL_BRANCH ]; then
    export ZUUL_BRANCH=master
fi
echo "ZUUL_BRANCH=$ZUUL_BRANCH ZUUL_REF=$ZUUL_REF"
export PYTHONUNBUFFERED=true
export DEVSTACK_GATE_TEMPEST_DISABLE_TENANT_ISOLATION=1
export DEVSTACK_GATE_TIMEOUT=120
export DEVSTACK_GATE_TEMPEST=1
export DEVSTACK_GATE_IRONIC=1
export DEVSTACK_GATE_NEUTRON=1
export DEVSTACK_GATE_VIRT_DRIVER=ironic
export TEMPEST_CONCURRENCY=1
export ZUUL_URL=http://testcimaster/p
export DEVSTACK_GATE_FEATURE_MATRIX=/opt/stack/ironic-xcat-test/features.yaml

if [ "$BRANCH_OVERRIDE" != "default" ] ; then
     export OVERRIDE_ZUUL_BRANCH=$BRANCH_OVERRIDE
fi

#export DEVSTACK_GATE_TEMPEST_REGEX='(?!.*\[.*\bslow\b.*\])(tempest.services.baremetal|tempest.api.baremetal|tempest.scenario.test_baremetal_*)'
export DEVSTACK_GATE_TEMPEST_REGEX='(?!.*\[.*\bslow\b.*\])(tempest.services.baremetal|tempest.api.baremetal)'
export DEVSTACK_GATE_CLEAN_LOGS=0
export RE_EXEC=true
export WORKSPACE=`pwd`


if [[ ! -e devstack-gate ]]; then
    git clone git://git.openstack.org/openstack-infra/devstack-gate
fi
cp devstack-gate/devstack-vm-gate-wrap.sh ./safe-devstack-vm-gate-wrap.sh
./safe-devstack-vm-gate-wrap.sh
GATE_RETVAL=$?
if [ $GATE_RETVAL -ne 0 ]; then
    #tar cvzf $BASE/logs.tar.gz $BASE/logs
    sudo scp -i /home/jenkins/.ssh/id_rsa -r /opt/stack/logs root@hypervisor-host:$JENKINS_LOG_WORKSPACE
    exit $GATE_RETVAL
fi
cd $BASE/ironic-xcat-test/testcase/
echo "xcat-ci log is  logs/xcat-ci.log"
sudo -H -u stack stdbuf -oL -eL ./test_stack.sh > $BASE/logs/xcat-ci.log
XCAT_CI_RETVAL=$?
sudo scp -i /home/jenkins/.ssh/id_rsa -r /opt/stack/logs root@hypervisor-host:$JENKINS_LOG_WORKSPACE
exit $XCAT_CI_RETVAL


