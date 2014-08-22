from oslo.config import cfg

from ironic.common import exception
from ironic.openstack.common import lockutils
from ironic.openstack.common import log
from stevedore import dispatch


LOG = log.getLogger(__name__)

driver_opts = [
        cfg.ListOpt('enabled_drivers',
                    default=['pxe_ipminative'],
                    help='temp test pxe_ipminative'),
]

CONF = cfg.CONF
CONF.unregister_opts(driver_opts)
CONF.register_opts(driver_opts)

EM_SEMAPHORE = 'extension_manager'


def get_driver(driver_name):
    """Simple method to get a ref to an instance of a driver.

    Driver loading is handled by the DriverFactory class. This method
    conveniently wraps that class and returns the actual driver object.

    :param driver_name: the name of the driver class to load
    :returns: An instance of a class which implements
              ironic.drivers.base.BaseDriver
    :raises: DriverNotFound if the requested driver_name could not be
             found in the "ironic.drivers" namespace.

    """

    try:
        factory = DriverFactory()
        return factory[driver_name].obj
    except KeyError:
        raise exception.DriverNotFound(driver_name=driver_name)


class DriverFactory(object):
    """Discover, load and manage the drivers available."""

    # NOTE(deva): loading the _extension_manager as a class member will break
    #             stevedore when it loads a driver, because the driver will
    #             import this file (and thus instantiate another factory).
    #             Instead, we instantiate a NameDispatchExtensionManager only
    #             once, the first time DriverFactory.__init__ is called.
    _extension_manager = None

    def __init__(self):
        if not DriverFactory._extension_manager:
            DriverFactory._init_extension_manager()

    def __getitem__(self, name):
        return self._extension_manager[name]

    # NOTE(deva): Use lockutils to avoid a potential race in eventlet
    #             that might try to create two driver factories.
    @classmethod
    @lockutils.synchronized(EM_SEMAPHORE, 'ironic-')
    def _init_extension_manager(cls):
        # NOTE(deva): In case multiple greenthreads queue up on this lock
        #             before _extension_manager is initialized, prevent
        #             creation of multiple NameDispatchExtensionManagers.
        if cls._extension_manager:
            return

        # NOTE(deva): Drivers raise "DriverNotFound" if they are unable to be
        #             loaded, eg. due to missing external dependencies.
        #             We capture that exception, and, only if it is for an
        #             enabled driver, raise it from here. If the exception
        #             is for a non-enabled driver, we suppress it.
        def _catch_driver_not_found(mgr, ep, exc):
            # NOTE(deva): stevedore loads plugins *before* evaluating
            #             _check_func, so we need to check here, too.
            if (isinstance(exc, exception.DriverLoadError) and
                    ep.name not in CONF.enabled_drivers):
                return
            raise exc

        def _check_func(ext):
            return ext.name in CONF.enabled_drivers

        cls._extension_manager = \
                dispatch.NameDispatchExtensionManager(
                        'ironic.drivers',
                        _check_func,
                        invoke_on_load=True,
                        on_load_failure_callback=_catch_driver_not_found)
        import pdb
        pdb.set_trace()
        LOG.info(_("Loaded the following drivers: %s"),
                cls._extension_manager.names())

    @property
    def names(self):
        """The list of driver names available."""
        return self._extension_manager.names()
