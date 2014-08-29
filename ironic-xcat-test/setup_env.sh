#!/bin/bash
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

BRANCH_OVERRIDE={branch-override}

if [ -n "$BRANCH_OVERRIDE" ]; then
    echo "export BRANCH_OVERRIDE=$BRANCH_OVERRIDE" >> env.sh
fi

if [ "$BRANCH_OVERRIDE" != "default" ] ; then
     echo "export OVERRIDE_ZUUL_BRANCH=$BRANCH_OVERRIDE" >> env.sh
fi

chmod 755 env.sh
scp -i /opt/ci_tmp/id_rsa ./env.sh jenkins@9.114.34.161:~/
