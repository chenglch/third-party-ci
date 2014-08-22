import gettext
gettext.install('ironic')
import re
from ironic.common import driver_factory
from oslo.config import cfg
from pyghmi import exceptions as pyghmi_exception
from ironic.common import boot_devices
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
import os

driver_opts = [
        cfg.ListOpt('enabled_drivers',
                    default=['pxe_ipminative','pxe_ssh','pxe_ipmitool'],
                    help='temp test pxe_ipminative'),
]

CONF = cfg.CONF
CONF.unregister_opts(driver_opts)
CONF.register_opts(driver_opts)
#
# CONF.import_opt('enabled_drivers',
#                 'pxe_ipminative',
#                 group='[DEFAULT')


INFO_DICT = {"ipmi_address": os.environ['IRONIC_NODE_IPMI_ADDRESS'],
             "ipmi_username": os.environ['IRONIC_NODE_IPMI_USERNAME'],
             "ipmi_password": os.environ['IRONIC_NODE_IPMI_PASSWORD'],
            }

# INFO_DICT = {"ipmi_address": "10.11.0.128",
#              "ipmi_username": "USERID",
#              "ipmi_password": "PASSW0RD",
#             }

driver = driver_factory.get_driver("pxe_ipminative")




