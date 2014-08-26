#!/bin/bash

# Make sure umask is sane
umask 022

# Keep track of the devstack directory
TOP_DIR=$(cd $(dirname "$0") && pwd)
source ${TOP_DIR}/config.sh

function get_field {
    local data field
    while read data; do
        if [ "$1" -lt 0 ]; then
            field="(\$(NF$1))"
        else
            field="\$$(($1 + 1))"
        fi
        echo "$data" | awk -F'[ \t]*\\|[ \t]*' "{print $field}"
    done
}

# Determinate is the given option present in the INI file
# ini_has_option config-file section option
function ini_has_option {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local file=$1
    local section=$2
    local option=$3
    local line

    line=$(sed -ne "/^\[$section\]/,/^\[.*\]/ { /^$option[ \t]*=/ p; }" "$file")
    $xtrace
    [ -n "$line" ]
}

# Set an option in an INI file
# iniset config-file section option value
function iniset {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local file=$1
    local section=$2
    local option=$3
    local value=$4

    [[ -z $section || -z $option ]] && return

    if ! grep -q "^\[$section\]" "$file" 2>/dev/null; then
        # Add section at the end
        echo -e "\n[$section]" >>"$file"
    fi
    if ! ini_has_option "$file" "$section" "$option"; then
        # Add it
        sed -i -e "/^\[$section\]/ a\\
$option = $value
" "$file"
    else
        local sep=$(echo -ne "\x01")
        # Replace it
        sed -i -e '/^\['${section}'\]/,/^\[.*\]/ s'${sep}'^\('${option}'[ \t]*=[ \t]*\).*$'${sep}'\1'"${value}"${sep} "$file"
    fi
    $xtrace
}

function delete_ironic_node {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local nodes=`ironic node-list | get_field 1 | grep -v uuid | grep -v ^$ | xargs`
    echo $nodes
    for node in $nodes; do
         echo "delete $node"
         ironic node-delete $node
    done
    $xtrace
}

function pepare_ironic_conductor {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    echo "setup ironic pxe_ipminative driver"
    iniset /etc/ironic/ironic.conf DEFAULT enabled_drivers "fake,pxe_ssh,pxe_ipmitool/enabled_drivers = fake,pxe_ssh,pxe_ipmitool,pxe_ipminative"
    iniset /etc/ironic/ironic.conf pxe tftp_server $IFONIC_API_IP_ADDRESS
    iniset /etc/ironic/ironic.conf conductor api_url "http://$IFONIC_API_IP_ADDRESS:6385"
    pip install pyghmi
    $xtrace
}
# para:
# @1:image path
# @2:disk format

function glance_add_image {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local image_path=$1
    local disk_format=$2
    local image_name=`basename $image_path`
    glance  image-create --name $image_name --is-public True --disk-format=$disk_format < $image_path
    $xtrace
}

function init_image {
    echo "init image"
    local image_name=`basename $IR_RAMFS_IMAGE_PATH`
    local ids=`glance image-list | grep $image_name | get_field 1 | xargs`
    if [ -n "$ids" ]; then
         for id in $ids; do
            echo "delete image $id"
            glance image-delete $id
         done
    fi

    local image_name=`basename $IR_KERNEL_IMAGE_PATH`
    local ids=`glance image-list | grep $image_name | get_field 1 | xargs`
    if [ -n "$ids" ]; then
         for id in $ids; do
            echo "delete image $id"
            glance image-delete $id
         done
    fi

    export IR_RAMFS_IMAGE_ID=`glance_add_image $IR_RAMFS_IMAGE_PATH ari | grep id | get_field 2`
    export IR_KERNEL_IMAGE_ID=`glance_add_image $IR_KERNEL_IMAGE_PATH aki | grep id | get_field 2`
}


function restart_ironic_conductor {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    echo "restart ironic conductor"
    local conductor=`ps -ef | grep ironic-conductor | grep -v grep | awk '{print $2}' | xargs`
    if [[ -n $conductor ]]; then
        sudo kill -9 $conductor
    fi
    sudo mkdir -p /var/log/ironic
    /usr/bin/python /usr/local/bin/ironic-conductor --config-file=/etc/ironic/ironic.conf \
    --log-file=/var/log/ironic/ironic-conductor.log 1>&2 2>/dev/null &
    delete_ironic_node
    $xtrace
}

function restart_dhcp_agent {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local pid=`ps -ef | grep neutron-dhcp-agent | grep -v grep | awk '{print $2}' | xargs`
    if [[ -n $pid ]]; then
        sudo kill -9 $pid
    fi
    iniset /etc/neutron/dhcp_agent.ini DEFAULT dnsmasq_config_file "/etc/dnsmasq/dnsmasq.conf"
    sudo mkdir -p /etc/dnsmasq
    chown -hR stack:stack /etc/dnsmasq
    echo "enable-tftp" > /etc/dnsmasq/dnsmasq.conf
    echo "tftp-root=/opt/stack/data/ironic/tftpboot" >> /etc/dnsmasq/dnsmasq.conf
    echo "dhcp-boot=pxelinux.0" >> /etc/dnsmasq/dnsmasq.conf
    mkdir -p /var/log/neutron
    python /usr/local/bin/neutron-dhcp-agent --config-file /etc/neutron/neutron.conf\
     --config-file=/etc/neutron/dhcp_agent.ini --log-file=/var/log/neutron/neutron-dhcp.log 1>&2 2>/dev/null &
    $xtrace
}

function mock_test {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    nosetests -sv ironic.tests.drivers.test_ipminative
    return $?
    $xtrace
}

function pysical_test {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    nosetests -sv ${CUR_DIR}/test_ipminative.py
    return $?
    $xtrace
}

function test_create_node {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    export CIRROS_IMAGE_UUID=`glance image-list | grep ami | grep cirros | awk '{print $2}'`
    unset -v IRONIC_NODE
    export IRONIC_NODE=`ironic node-create --driver pxe_ipminative -i ipmi_address=$IRONIC_NODE_IPMI_ADDRESS   -i ipmi_username=$IRONIC_NODE_IPMI_USERNAME \
    -i ipmi_password=$IRONIC_NODE_IPMI_PASSWORD -i pxe_deploy_kernel=$IR_KERNEL_IMAGE_ID -i pxe_deploy_ramdisk=$IR_RAMFS_IMAGE_ID \
    -i pxe_image_source=$CIRROS_IMAGE_UUID -i pxe_root_gb=40  -p memory_mb=2048 -p cpus=8 -p local_gb=10 -p cpu_arch=x86_64\
     | grep uuid | grep -v chassis_uuid | \
     awk '{print $4}'`

#    export IRONIC_NODE=`ironic node-create  --driver pxe_ssh -i pxe_deploy_kernel=$IR_KERNEL_IMAGE_ID -i pxe_deploy_ramdisk=$IR_RAMFS_IMAGE_ID\
#     -i ssh_virt_type=virsh -i ssh_address=9.114.34.161 -i ssh_port=22 -i ssh_username=stack -i \
#     ssh_key_filename=/opt/stack/data/ironic/ssh_keys/ironic_key\
#      -p cpus=1 -p memory_mb=512 -p local_gb=10 -p cpu_arch=x86_64\
#       | grep uuid | grep -v chassis_uuid |  awk '{print $4}'`

    # just test pxe_ssh
    IRONIC_NODE_MAC=virsh dumpxml baremetalbrbm_0 | grep "mac address=" | awk -F "[']" '{print $2}'
    echo "Ironic Node $IRONIC_NODE created "
    #ironic port-create --address 52:54:00:b1:cc:13 --node_uuid $IRONIC_NODE
    ironic node-show $IRONIC_NODE
    ironic port-create --address $IRONIC_NODE_MAC --node_uuid $IRONIC_NODE
    echo "ironic node create sleep $IRONIC_NODE_CREATE_WAIT1"
    sleep ${IRONIC_NODE_CREATE_WAIT1}s
    power_state=`ironic node-show $IRONIC_NODE | grep power_state | grep -v target_power_state | get_field 2`
    if [[ -z $power_state ]] || [[ $power_state == "None" ]]; then
        echo "ironic node create sleep $IRONIC_NODE_CREATE_WAIT2"
        sleep ${IRONIC_NODE_CREATE_WAIT2}s
        power_state=`ironic node-show $IRONIC_NODE | grep power_state | grep -v target_power_state | get_field 2`
    fi

    if [[ $power_state == "power on" ]];then
        ironic node-set-power-state $IRONIC_NODE off;
        echo "ironic node power off sleep $IRONIC_NODE_POWER_OFF_WAIT"
        sleep ${IRONIC_NODE_POWER_OFF_WAIT}s
    elif [[ -z $power_state ]] || [[ $power_state == "None" ]]; then
        echo "get power info error $0 ---line $LINENO"
        return 1;
    fi
    power_state=`ironic node-show $IRONIC_NODE | grep power_state | grep -v target_power_state | get_field 2`
    if [[ $power_state == "power off" ]]; then
        return 0;
    else
        echo "ironic power off error $0 ---line $LINENO"
        return 1;
    fi
    $xtrace
}

function test_nova_boot {
    export CIRROS_IMAGE_UUID=`glance image-list | grep ami | grep cirros | awk '{print $2}'`
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local bare_flavor=`nova flavor-list | grep baremetal`
    echo "deploy flavor $bare_flavor $0 ---line $LINENO"
    if [[ -z $bare_flavor ]]; then
        nova flavor-create --ephemeral 0 baremetal auto 512 10 1
        echo "create flavor $bare_flavor $0 ---line $LINENO"
    fi
    local net_id=`neutron net-list | grep private | get_field 1`
    echo "create net_id $net_id $0 ---line $LINENO"
    local instance_uuid=`nova boot --flavor baremetal --image $CIRROS_IMAGE_UUID test_ipminative --availability-zone nova:$HOST\
    --nic net-id=$net_id | grep id | head -n 1 | get_field 2`
    echo "nova instance $instance_uuid created"
    sleep ${NOVA_DEPLOY_START_WAIT}s
    local provision_state=`ironic node-list | grep $instance_uuid | get_field 4`
    if [[ $provision_state != "deploying" ]] && [[ $provision_state != "wait call-back" ]]; then
        echo "deploy $instance_uuid failed $0 ---line $LINENO"
        return 1
    fi
    sleep ${NOVA_POWER_ON_WAIT}s
    local power_state=`ironic node-list | grep $instance_uuid | get_field 3`
    if [[ $power_state != "power on" ]]; then
        echo "power on $instance_uuid failed $0 ---line $LINENO"
        return 1
    fi
    sleep ${NOVA_DEPLOY_ACTIVE_WAIT}s
    local task_state=`ironic node-list | grep $instance_uuid | get_field 4`
    if [[ $task_state == "active" ]]; then
        nova list
        ironic node-set-power-state $IRONIC_NODE off
        return 0
    fi
    local i=0
    while(($i<$RETRY_TIME))
    do
        local task_state=`ironic node-list | grep $instance_uuid | get_field 4`
        if [[ $task_state == "active" ]]; then
            nova list
            ironic node-set-power-state $IRONIC_NODE off
            return 0
        fi
        sleep ${NOVA_SCAN_WAIT}s
        i=$(($i+1))
    done
    echo "Download $instance_uuid failed $0 ---line $LINENO"
    return 1
}
echo "setup ipminative environment"
#mysql -psecret -uroot -h127.0.0.1 -e "delete from ironic.ports;"
#mysql -psecret -uroot -h127.0.0.1 -e "delete from ironic.nodes;"
source $BASE/new/devstack/openrc admin admin

pepare_ironic_conductor
restart_dhcp_agent
restart_ironic_conductor
init_image

if mock_test; then
    echo "xcat.ironic.third-party-ci.testcase.mock_tests ...ok"
else
    echo "xcat.ironic.third-party-ci.testcase.mock_tests ...fail"
    exit 1
fi

if pysical_test; then
    echo "xcat.ironic.third-party-ci.testcase.pysical_test ...ok"
else
    echo "xcat.ironic.third-party-ci.testcase.pysical_test ...fail"
    exit 1
fi

if test_create_node; then
    echo "xcat.ironic.third-party-ci.testcase.test_create_node ... ok"
else
    echo "xcat.ironic.third-party-ci.testcase.test_create_node ... fail"
    exit 1
fi

if test_nova_boot; then
    echo "xcat.ironic.third-party-ci.testcase.test_nova_boot ... ok"
else
    echo "xcat.ironic.third-party-ci.testcase.test_nova_boot ... fail"
    exit 1
fi





