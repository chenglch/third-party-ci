import gettext
import os
gettext.install('ironic')
import re
from oslo.config import cfg
from pyghmi import exceptions as pyghmi_exception
import time
from ironic.common import boot_devices
from ironic.common import driver_factory
from ironic.common import exception
from ironic.common import states
from ironic.common import utils
from ironic.conductor import task_manager
from ironic.db import api as db_api
from ironic.drivers.modules import ipminative
from ironic.openstack.common import context
from ironic.tests import base
from ironic.tests.conductor import utils as mgr_utils
from ironic.tests.db import base as db_base
from ironic.tests.db import utils as db_utils
from ironic.tests.objects import utils as obj_utils

CONF = cfg.CONF

INFO_DICT = {"ipmi_address": os.environ['IRONIC_NODE_IPMI_ADDRESS'],
             "ipmi_username": os.environ['IRONIC_NODE_IPMI_USERNAME'],
             "ipmi_password": os.environ['IRONIC_NODE_IPMI_PASSWORD'],
            }

driver_opts = [
        cfg.ListOpt('enabled_drivers',
                    default=['pxe_ipminative','pxe_ssh','pxe_ipmitool'],
                    help='temp test pxe_ipminative'),
]

command_opts = [
        cfg.IntOpt('min_command_interval',
                   default=5,
                   help='ipmi command interval'),
]
LAST_CMD_TIME = {}

CONF = cfg.CONF
# must unregister first, otherwise pxe_ipmitool is the defaut opts
CONF.unregister_opts(driver_opts)
CONF.unregister_opts(command_opts,group='ipmi')
CONF.register_opts(driver_opts)
CONF.register_opts(command_opts,group='ipmi')

def _ipmitool_cmd(info,args):
        cmd = ["ipmitool", "-I", "lanplus", "-H",
               info.get('address'),
               "-U",info.get('username'),
               "-P",info.get('password'),
               ]
        cmd.extend(args.split(' '))
        time_till_next_poll = CONF.ipmi.min_command_interval -(
                        time.time() - LAST_CMD_TIME.get(info['address'],0))
        if time_till_next_poll > 0:
            time.sleep(time_till_next_poll)
        try:
            out, err = utils.execute(*cmd)
            if err:
                return False
        except Exception:
            return False
        finally:
            LAST_CMD_TIME[info['address']] = time.time()
        return out

class IPMINativePowerMethodTestCase(db_base.DbTestCase):
    """Test cases for ipminative power methods."""

    def setUp(self):
        super(IPMINativePowerMethodTestCase, self).setUp()
        self.context = context.get_admin_context()
        self.driver = driver_factory.get_driver("pxe_ipminative")
        self.node = obj_utils.create_test_node(self.context,
                                               driver='pxe_ipminative',
                                               driver_info=INFO_DICT)
        #self.dbapi = db_api.get_instance()
        self.info = ipminative._parse_driver_info(self.node)

    def test__parse_driver_info(self):
        # make sure we get back the expected things
        self.assertIsNotNone(self.info.get('address'))
        self.assertIsNotNone(self.info.get('username'))
        self.assertIsNotNone(self.info.get('password'))
        self.assertIsNotNone(self.info.get('uuid'))

        # make sure error is raised when info, eg. username, is missing
        info = dict(INFO_DICT)
        del info['ipmi_username']

        node = obj_utils.get_test_node(self.context, driver_info=info)
        self.assertRaises(exception.MissingParameterValue,
                          ipminative._parse_driver_info,
                          node)
    #  ipmitool -I lan -H 10.11.0.107 -U USERID -P PASSW0RD power status
    def test__power_status(self):
        args ="power status"
        out = _ipmitool_cmd(self.info,args)
        self.assertIsNot(False,out)
        if out:
            # out :Chassis Power is off , Chassis Power is on
            out = out.strip().split()[-1]
            state = ipminative._power_status(self.info).strip().split()[-1]
            self.assertEqual(out, state)

class IPMINativeBootdevTestCase(db_base.DbTestCase):
    def setUp(self):
        super(IPMINativeBootdevTestCase, self).setUp()
        self.context = context.get_admin_context()
        self.driver = driver_factory.get_driver("pxe_ipminative")
        self.node = obj_utils.create_test_node(self.context,
                                               driver='pxe_ipminative',
                                               driver_info=INFO_DICT)
        self.dbapi = db_api.get_instance()
        self.info = ipminative._parse_driver_info(self.node)


    def test_set_boot_device_pxe(self):
        with task_manager.acquire(self.context,
                                  self.node.uuid) as task:
            self.driver.management.set_boot_device(task, 'pxe')
        # PXE is converted to 'net' internally by ipminative
        args = "chassis bootparam get 5"
        #Boot Device Selector : Force PXE
        out = _ipmitool_cmd(self.info,args)
        self.assertIsNot(False,out)
        re_obj = re.search('Boot Device Selector : (.+)?\n', out)
        if re_obj:
            boot_selector = re_obj.groups('')[0]
            self.assertIn('PXE',boot_selector)

    def test_set_boot_device_hd(self):
        with task_manager.acquire(self.context,
                                  self.node.uuid) as task:
            self.driver.management.set_boot_device(task, 'disk')
        # PXE is converted to 'net' internally by ipminative
        args = "chassis bootparam get 5"
        #Boot Device Selector : Force Hard-Drive
        out = _ipmitool_cmd(self.info,args)
        self.assertIsNot(False,out)
        re_obj = re.search('Boot Device Selector : (.+)?\n', out)
        if re_obj:
            boot_selector = re_obj.groups('')[0]
            self.assertIn('Hard-Drive',boot_selector)





