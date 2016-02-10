# -*- coding: utf-8 -*-
""" scn.py
 @brief  SCNミドルウェアPython用API
 @author (SEC) M.Toyoda
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
    """終了時SCN離脱処理
    """
    for scnm in _scnms:
        scnm.finalize()

    raise KeyboardInterrupt

signal.signal(signal.SIGTERM, leave_scn)
signal.signal(signal.SIGINT,  leave_scn)

class SCNManager:
    """SCNManagerクラス
    """

    RPC_IP_ADDRESS         = "127.0.0.1"
    RPC_INITIAL_IP_ADDRESS = "127.0.0.1"
    RPC_INITIAL_TX_PORT    = 10000
    RPC_CLIENT_TIMEOUT     = 40

    def __init__(self, callback=None):
        """コンストラクタ
        _callback    -- [func] データ受信用コールバック関数
        """

        self._service_id = None
        self._client     = None
        self._piax       = PIAXAccessor()

        # SCNミドルウェアとの接続ポートを取得する。
        addr = msgpackrpc.Address(self.RPC_INITIAL_IP_ADDRESS, self.RPC_INITIAL_TX_PORT)
        client = msgpackrpc.Client(addr, timeout = self.RPC_CLIENT_TIMEOUT)

        try:
            self.rpc_tx_port, self.rpc_rx_port = client.call('connect_app')

            # API用のRPCクライアントを作成する。
            addr = msgpackrpc.Address(self.RPC_IP_ADDRESS, self.rpc_tx_port)
            self._client = msgpackrpc.Client(addr, timeout = self.RPC_CLIENT_TIMEOUT)
            #self._client = msgpackrpc.Client(addr, timeout = self.RPC_CLIENT_TIMEOUT, builder=tcp)

            # API用のRPCサーバを作成する。
            self.publisher = Publisher()
            self.publisher.add_data_listener(callback)
            self.server    = msgpackrpc.Server(self.publisher)
            #self.server    = msgpackrpc.Server(self.publisher, builder=tcp)
            self.server.listen(msgpackrpc.Address("0.0.0.0", self.rpc_rx_port))

            # スレッドを開始する。
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
        """RPC受信スレッド開始メソッド
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
        """サービス参加API
        service_name -- [str] サービス名
        service_info -- [dict] サービスの情報
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
        """サービス情報変更API
        service_id    -- [str] サービスID
        service_info  -- [dict] サービスの情報
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
        """サービス検索API
        query -- [dict] サービスの検索条件
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
        """サービス離脱API
        service_id -- [str] サービスID
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
        """データ送信API
        data            -- [str/dict] 送信データ
        channel_id -- [str]      チャネルID
        sync            -- [boolean]  Trueの時、送信の完了を待ち合せる
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
        """DSN記述生成API
        table_name -- [str] テーブル名
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
        """オーバレイ生成API
        overlay_name -- [str]  オーバレイ名
        dsn_spec     -- [str]  DSN記述
        callback     -- [func] メッセージ受信用コールバック
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
        """オーバレイ削除API
        overlay_id -- [str]  オーバレイID
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
        """チャネル取得API
        channel_id -- [str]  チャネルID
        """
        try:
            result = self._client.call('get_channel', channel_id)

            return json.loads(result)

        except Exception as e:
            logging.debug("%s", str(e))
            raise


    def get_piax_data(self, values = [], method = "rect", params = [122.56, 20.25, 31.04, 25.09]):
        """ PIAX基盤データ取得API
        values -- [list<str>] 取得するデータパス
        method -- [str]       検索に使用するメソッド名
        params -- [list]      検索時のパラメータ
        """
        return self._piax.get_data(values, method, params)


    def get_piax_sensors(self, method = "rect", params = [122.56, 20.25, 31.04, 25.09]):
        """ PIAX基盤センサー取得API
        method -- [str]       検索に使用するメソッド名
        params -- [list]      検索時のパラメータ
        """
        return self._piax.get_sensors(method, params)


    def _check_join(self):
        if self._service_id is None:
            raise Exception("service has not been joined.")


    def _calc_size(self, o):
        """データサイズ計算処理
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
    """イベントハンドラクラス
    """
    def __init__(self):
        self._data_callback = None
        self._overlay_callback = {}

    def add_data_listener(self, callback):
        """ データ受信用コールバック設定メソッド
        callback -- [func] データ受信時のコールバック
        """
        self._data_callback = callback

    def add_overlay_listener(self, overlay_id, callback):
        """ メッセージ受信用コールバック設定メソッド
        overlay_id -- [str]  データを受信するオーバレイID
        callback   -- [func] データ受信時のコールバック
        """
        self._overlay_callback[overlay_id] = callback

    def remove_overlay_listener(self, overlay_id):
        """ メッセージ受信用コールバック削除メソッド
        overlay_id -- [str]  データを受信するオーバレイID
        """
        self._overlay_callback.pop(overlay_id, None)

    def receive_data(self, data, data_size, channel_id):
        """データ受信用コールバックメソッド
        data -- [str/dict]       受信データ
        data_size -- [int]       受信データサイズ
        channel_id -- [str] チャネルID
        """
        logging.debug("Publisher::receive_data() is called.")
        logging.debug("data(%d bytes) has been received. (channel ID = %s)", data_size, channel_id)

        if self._data_callback is not None:
            thread = threading.Thread(target=self._data_callback, args=(data, channel_id))
            thread.setDaemon(True)
            thread.start()

        gc.collect()

    def receive_message(self, overlay_id, message):
        """メッセージ受信コールバックメソッド
        message    -- [str] 受信メッセージ
        overlay_id -- [str] オーバーレイID
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
    """ PIAX基盤へのアクセスクラス
    """
    PIAX_URL_BASE           = "192.168.240.12:8090"
    PIAX_URL_DATA_FORMAT    = "http://{0}/sensors/discquery/{1}/values/{2}"
    PIAX_URL_SENSORS_FORMAT = "http://{0}/sensors/discquery/{1}"

    QUERY_FORAT   = "Location in {0}({1})"
    SELECT_COMMON = ["Location%2FLongitude", "Location%2FLatitude"]
    HEADER_COOKIE = "API_KEY=vqF+WleHlo094F2U5YhHlVhFo5J12u4Q86z2CR6COFOO7VTKgGKoMsv1YXsk7X4P3vnxl32mKEg="
    HEADER_ACCEPT = "application/json"

    def get_data(self, values = [], method = "rect", params = [122.56, 20.25, 31.04, 25.09]):
        """ GETメソッドを実行する
        values -- [list<str>] 取得するデータパス
        method -- [str]       検索に使用するメソッド名
        params -- [list]      検索時のパラメータ
        """
        where = urllib.quote(self.QUERY_FORAT.format(method, ",".join([str(param) for param in params])))
        # valuesの"/"がquote非対応のため、個別に置換
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
        """ GETメソッドを実行する
        method -- [str]       検索に使用するメソッド名
        params -- [list]      検索時のパラメータ
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

