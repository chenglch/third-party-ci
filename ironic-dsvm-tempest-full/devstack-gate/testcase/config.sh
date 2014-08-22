HOST="testcislave"
IR_RAMFS_IMAGE_PATH="/opt/stack/data/glance/ir-deploy.initramfs"
IR_KERNEL_IMAGE_PATH="/opt/stack/data/glance/ir-deploy.kernel"

IRONIC_NODE_MAC="e4:1f:13:ed:8b:aa"
export IRONIC_NODE_IPMI_ADDRESS="10.11.0.128"
export IRONIC_NODE_IPMI_USERNAME="USERID"
export IRONIC_NODE_IPMI_PASSWORD="PASSW0RD"
IRONIC_NODE_CREATE_WAIT1=45
IRONIC_NODE_CREATE_WAIT2=30
IRONIC_NODE_POWER_OFF_WAIT=70

NOVA_DEPLOY_START_WAIT=60
NOVA_POWER_ON_WAIT=60
NOVA_DEPLOY_ACTIVE_WAIT=360

export BASE=/opt/stack
