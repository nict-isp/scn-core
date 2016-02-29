# -*- coding: utf-8 -*-
""" scn.py
 @brief  SCN middleware API for Python
 @author NICT

 Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
 GPL3, see LICENSE for more details. 
"""
import sys
import msgpackrpc
import threading
import logging
import json
import signal
import tcp
import gc

#logger = logging.getLogger('scn')
logging.basicConfig(level=logging.INFO,
                    format='[%(asctime)s] %(levelname)s -- : %(message)s',
                    filename='./scn.log',
                    filemode='w')

_scnms = []

def leave_scn(num, frame):
    """At the end of SCN middleware leave processing
    """
    for scnm in _scnms:
        scnm.finalize()

    raise KeyboardInterrupt

signal.signal(signal.SIGTERM, leave_scn)
signal.signal(signal.SIGINT,  leave_scn)

class SCNManager:
    """SCNManager class
    """

    RPC_IP_ADDRESS         = "127.0.0.1"
    RPC_INITIAL_IP_ADDRESS = "127.0.0.1"
    RPC_INITIAL_TX_PORT    = 10000
    RPC_CLIENT_TIMEOUT     = 40

    def __init__(self, callback=None):
        """constructor
        _callback    -- [func] callback function for data reception
        """

        self._service_id = None
        self._client     = None
        self._piax       = PIAXAccessor()

        # To get a connection port of the SCN middleware.
        addr = msgpackrpc.Address(self.RPC_INITIAL_IP_ADDRESS, self.RPC_INITIAL_TX_PORT)
        client = msgpackrpc.Client(addr, timeout = self.RPC_CLIENT_TIMEOUT)

        try:
            self.rpc_tx_port, self.rpc_rx_port = client.call('connect_app')

            # To create an RPC client for API.
            addr = msgpackrpc.Address(self.RPC_IP_ADDRESS, self.rpc_tx_port)
            self._client = msgpackrpc.Client(addr, timeout = self.RPC_CLIENT_TIMEOUT)
            #self._client = msgpackrpc.Client(addr, timeout = self.RPC_CLIENT_TIMEOUT, builder=tcp)

            # To create an RPC server for the API.
            self.publisher = Publisher()
            self.publisher.add_data_listener(callback)
            self.server    = msgpackrpc.Server(self.publisher)
            #self.server    = msgpackrpc.Server(self.publisher, builder=tcp)
            self.server.listen(msgpackrpc.Address("0.0.0.0", self.rpc_rx_port))

            # To start a thread.
            self.thread = threading.Thread(target=self._run)
            self.thread.start()

            _scnms.append(self)

        except msgpackrpc.error.TransportError as e:
            message = "can't connect to RPC Server of SCN middleware." + \
                      "(IP address = %s, port = %d)" % (self.RPC_INITIAL_IP_ADDRESS, self.RPC_INITIAL_TX_PORT)
            logging.debug(message)
            logging.debug("%s", str(e))
            raise Exception(message)

        except Exception as e:
            logging.debug("%s", str(e))
            raise


    def _run(self):
        """RPC reception thread start method
        """
        logging.debug("RPC receive server start. (RPC RX port = %s)", str(self.rpc_rx_port))
        logging.debug("RPC TX port = %s", str(self.rpc_tx_port))

        self.server.start()


    def finalize(self):
        try:
            self.leave_service()
        except Exception as e:
            logging.debug("%s", str(e))
        try:
            self.server.stop()
        except Exception as e:
            logging.debug("%s", str(e))


    def join_service(self, service_name, service_info):
        """API for the service to join
        service_name -- [str]  Service name
        service_info -- [dict] Service informaion
        """
        try:
            self._service_id = self._client.call('join_service', service_name, service_info, self.rpc_rx_port)

            logging.debug("service name(=%s) was joined successfully. (service ID =%s)", service_name, self._service_id)
            return self._service_id

        except msgpackrpc.error.RPCError as e:
            message = "service name(=%s) failed to join. %s" % (service_name, str(e))
            logging.debug("%s", message)
            raise Exception(message)

        except Exception as e:
            logging.debug("%s", str(e))
            raise


    def update_service(self, service_info):
        """API for the service information to change
        service_id    -- [str]  Service ID
        service_info  -- [dict] Service information
        """
        self._check_join()

        try:
            self._client.call('update_service', self._service_id, service_info)

            logging.debug("service ID(=%s) was updated successfully. (info = %s)", self._service_id, service_info)


        except msgpackrpc.error.RPCError as e:
            message = "service ID(=%s) failed to update. %s" % (self._service_id, str(e))
            logging.debug("%s", message)
            raise Exception(message)

        except Exception as e:
            logging.debug("%s", str(e))
            raise


    def discovery_service(self, query):
        """API for the service to search
        query -- [dict] Search conditions of service
        """
        try:
            result = self._client.call('discovery_service', query)
            list   = json.loads(result)

            logging.debug("service discovery was executed successfully. (%d hits, result = %s)", len(list), result)

            return list

        except msgpackrpc.error.RPCError as e:
            message = "discovery service failed. %s" % (str(e))
            logging.debug("%s", message)
            raise Exception(message)

        except Exception as e:
            logging.debug("%s", str(e))
            raise


    def leave_service(self):
        """API for the service to leave
        service_id -- [str] Service ID
        """
        self._check_join()

        try:
            self._client.call('leave_service', self._service_id)
            self._service_id = None

            logging.debug("service ID(=%s) was leaved successfully.", self._service_id)

        except msgpackrpc.error.RPCError as e:
            message = "service ID(=%s) failed to leave. %s" % (self._service_id, str(e))
            logging.debug("%s", message)
            raise Exception(message)

        except Exception as e:
            logging.debug("%s", str(e))
            raise


    def send_data(self, data, channel_id=None, sync=False):
        """API for sending data
        data       -- [str/dict] Transmission data
        channel_id -- [str]      Channel ID
        sync       -- [boolean]  When True, the wait for the completion of the transmission
        """
        self._check_join()
        data_size = self._calc_size(data)

        try:
            channel_id_list = self._client.call('send_data', self._service_id, data, data_size, channel_id, sync)
            gc.collect()

            logging.debug("data(%d bytes) has been sent successfully. " + \
                          "(channel ID = %s)", data_size, channel_id_list, sync)

            return json.loads(channel_id_list)

        except msgpackrpc.error.RPCError as e:
            message = "data(%d bytes) failed to send. %s" % (data_size, str(e))
            logging.debug("%s", message)
            raise Exception(message)

        except Exception as e:
            logging.debug("%s", str(e))
            raise


    def create_dsn(self, table_name, event_data_model):
        """API for the DSN description to generate
        table_name       -- [str]  Table name
        event_data_model -- [dict] Event Data Model
        """
        try:
            overlay_name, dsn_desc = self._client.call('create_dsn', table_name, event_data_model)

            logging.debug("create dsn has been successfully. \n%s", overlay_name)
            return (overlay_name, dsn_desc)

        except msgpackrpc.error.RPCError as e:
            message = "DSN description failed to create. %s" % (str(e))
            logging.debug("%s", message)
            raise Exception(message)

        except Exception as e:
            logging.debug("%s", str(e))
            raise


    def create_overlay(self, overlay_name, dsn_spec, callback=None):
        """API for the overlay to generate
        overlay_name -- [str]  Overlay name
        dsn_spec     -- [str]  DSN description
        callback     -- [func] Call back for Message reception
        """
        try:
            overlay_id = self._client.call('create_overlay', overlay_name, dsn_spec, self.rpc_rx_port)
            self.publisher.add_overlay_listener(overlay_id, callback)

            logging.debug("overlay name(=%s) was created successfully. " + \
                          "(overlay id = %s)", overlay_name, overlay_id)

            return overlay_id

        except msgpackrpc.error.RPCError as e:
            message = "overlay name(=%s) failed to create. %s" % (overlay_name, str(e))
            logging.debug("%s", message)
            raise Exception(message)

        except Exception as e:
            logging.debug("%s", str(e))
            raise

    def delete_overlay(self, overlay_id):
        """API for the overlay to delete
        overlay_id -- [str]  Overlay ID
        """
        try:
            self._client.call('delete_overlay', overlay_id)
            logging.debug("overlay id(=%s) was deleted successfully. ", overlay_id)

        except msgpackrpc.error.RPCError as e:
            message = "overlay id(=%s) failed to delete. %s" % (overlay_id, str(e))
            logging.debug("%s", message)
            raise Exception(message)

        except Exception as e:
            logging.debug("%s", str(e))
            raise

        finally:
            self.publisher.remove_overlay_listener(overlay_id)


    def get_channel(self, channel_id):
        """API for get the channel
        channel_id -- [str]  Channel ID
        """
        try:
            result = self._client.call('get_channel', channel_id)

            return json.loads(result)

        except Exception as e:
            logging.debug("%s", str(e))
            raise


    def get_piax_data(self, values = [], method = "rect", params = [122.56, 20.25, 31.04, 25.09]):
        """API for get the PIAX data
        values -- [list<str>] Data path to get
        method -- [str]       The name of the method used to search
        params -- [list]      Parameters of at the search time
        """
        return self._piax.get_data(values, method, params)


    def get_piax_sensors(self, method = "rect", params = [122.56, 20.25, 31.04, 25.09]):
        """API for get the PIAX sensor
        method -- [str]       The name of the method used to search
        params -- [list]      Parameters of at the search time
        """
        return self._piax.get_sensors(method, params)


    def _check_join(self):
        if self._service_id is None:
            raise Exception("service has not been joined.")


    def _calc_size(self, o):
        """Data size calculation processing
        """
        if isinstance(o, dict):
            size = 2    #{}
            sep = 0
            for k, v in o.items():
                size += self._calc_size(k) + 2 + sep  #:
                if v is None:
                    size += 4   #null
                else:
                    size += self._calc_size(v)
                sep = 2     #,
            return size

        elif isinstance(o, list):
            size = 2    #[]
            sep = 0
            for v in o:
                size += self._calc_size(v) + sep
                sep = 2     #,
            return size

        elif isinstance(o, str):
            return len(o) + 2   #""

        elif isinstance(o, unicode):
            return len(o) + 3   #u""

        else:
            return len(str(o))


class Publisher(object):
    """Event handler class
    """
    def __init__(self):
        self._data_callback = None
        self._overlay_callback = {}

    def add_data_listener(self, callback):
        """Method to set the callback for data reception
        callback -- [func] Call back at the time of data reception
        """
        self._data_callback = callback

    def add_overlay_listener(self, overlay_id, callback):
        """Method to set the callback for message reception
        overlay_id -- [str]  Overlay ID to receive data
        callback   -- [func] Call back at the time of data reception
        """
        self._overlay_callback[overlay_id] = callback

    def remove_overlay_listener(self, overlay_id):
        """Method to remove the callback for message reception
        overlay_id -- [str]  Overlay ID to receive data
        """
        self._overlay_callback.pop(overlay_id, None)

    def receive_data(self, data, data_size, channel_id):
        """Callback method for receiving data
        data       -- [str/dict]  Received data
        data_size  -- [int]       Received data size
        channel_id -- [str]       Channel ID
        """
        logging.debug("Publisher::receive_data() is called.")
        logging.debug("data(%d bytes) has been received. (channel ID = %s)", data_size, channel_id)

        if self._data_callback is not None:
            thread = threading.Thread(target=self._data_callback, args=(data, channel_id))
            thread.setDaemon(True)
            thread.start()

        gc.collect()

    def receive_message(self, overlay_id, message):
        """Call back setting method for data receiving
        message    -- [str] Received message
        overlay_id -- [str] Overlay ID
        """
        logging.debug("Publisher::receive_message() is called.")
        logging.debug("message has been received. (overlay id = %s, message = %s)", overlay_id, message)

        callback = self._overlay_callback.get(overlay_id)
        if callback is not None:
            thread = threading.Thread(target=callback, args=(message,))
            thread.setDaemon(True)
            thread.start()

        gc.collect()

import urllib, urllib2

class PIAXAccessor:
    """Access class to PIAX
    """
    PIAX_URL_BASE           = "192.168.240.12:8090"
    PIAX_URL_DATA_FORMAT    = "http://{0}/sensors/discquery/{1}/values/{2}"
    PIAX_URL_SENSORS_FORMAT = "http://{0}/sensors/discquery/{1}"

    QUERY_FORAT   = "Location in {0}({1})"
    SELECT_COMMON = ["Location%2FLongitude", "Location%2FLatitude"]
    HEADER_COOKIE = "API_KEY=vqF+WleHlo094F2U5YhHlVhFo5J12u4Q86z2CR6COFOO7VTKgGKoMsv1YXsk7X4P3vnxl32mKEg="
    HEADER_ACCEPT = "application/json"

    def get_data(self, values = [], method = "rect", params = [122.56, 20.25, 31.04, 25.09]):
        """Perform the GET method
        values -- [list<str>] Data path to get
        method -- [str]       The name of the method used to search
        params -- [list]      Parameters of at the search time
        """
        where = urllib.quote(self.QUERY_FORAT.format(method, ",".join([str(param) for param in params])))
        # For the "/" is values of quote non-compliant, to replace individually.
        quoted_values = [urllib.quote(value).replace('/', '%2F') for value in values]
        quoted_values.extend(self.SELECT_COMMON)
        select = ",".join(list(set(quoted_values)))
        url = self.PIAX_URL_DATA_FORMAT.format(self.PIAX_URL_BASE, where, select)
        logging.info('[Get] %s', url)

        try:
            opener = urllib2.build_opener()
            opener.addheaders.append(('Cookie', self.HEADER_COOKIE))
            opener.addheaders.append(('Accept', self.HEADER_ACCEPT))
            f = opener.open(url)
            return f.read()

        except urllib2.URLError, e:
            if hasattr(e, 'reason'):
                logging.error('We failed to reach a server.')
                logging.error('Reason: %s', e.reason)
            elif hasattr(e, 'code'):
                logging.error('The server couldn\'t fulfill the request.')
                logging.error('Error code: %s', e.code)
            raise

    def get_sensors(self, values = [], method = "rect", params = [122.56, 20.25, 31.04, 25.09]):
        """Perform the GET method
        method -- [str]       The name of the method used to search
        params -- [list]      Parameters of at the search time
        """
        where = urllib.quote(self.QUERY_FORAT.format(method, ",".join([str(param) for param in params])))
        url = self.PIAX_URL_SENSORS_FORMAT.format(self.PIAX_URL_BASE, where)
        logging.info('[Get] %s', url)

        try:
            opener = urllib2.build_opener()
            opener.addheaders.append(('Cookie', self.HEADER_COOKIE))
            opener.addheaders.append(('Accept', self.HEADER_ACCEPT))
            f = opener.open(url)
            return f.read()

        except urllib2.URLError, e:
            if hasattr(e, 'reason'):
                logging.error('We failed to reach a server.')
                logging.error('Reason: %s', e.reason)
            elif hasattr(e, 'code'):
                logging.error('The server couldn\'t fulfill the request.')
                logging.error('Error code: %s', e.code)
            raise

