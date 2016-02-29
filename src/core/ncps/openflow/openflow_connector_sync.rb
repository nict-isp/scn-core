#-*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative '../../utils'
require_relative '../../utility/semaphore'
require_relative './openflow_connector'
require 'json'

#= OpenFlowネットワーク向けの通信ライブラリ
# 元クラスの非同期の通信処理を同期化し、タイムアウト管理を行なう。
#
#@author NICT
#
class OpenFlowConnectorSync < OpenFlowConnector

    # セマフォを使って同期処理を行なう。
    #
    #@yield [callback] 非同期処理を実行するブロック
    #@yieldparam [Callable] callback 非同期処理から結果を受け取るためのコールバック
    #@return [Hash] 問合せ結果
    #@raise [NetworkError] ネットワーク構成に障害がある場合
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #@raise [InternalServerError] NCPSサーバー内部でエラーが発生した場合
    #
    def sync_do()
        semaphore = Semaphore.new()
        yield semaphore.get_callback()
        result = semaphore.acquire()
        check_error(result)
        return result
    end

    # OFCとの接続を実施。自IPからゲートウェイを選定する。
    #
    #@param [Callable] on_push OFCからのPUSH通知呼出コールバック
    #@return [String] 取得したミドルウェアID
    #@raise [NetworkError] ネットワーク構成に障害がある場合
    #@raise [InternalServerError] NCPSサーバー内部でエラーが発生した場合
    #@raise [Timeout::Error] 要求がタイムアウトした場合
    #
    def init(on_push = nil)
        result = sync_do{ |callback| super(callback, on_push) }
        return result["scn_id"], result["svs_srv_ip"]
    end

    # OFCの双方向パス作成コマンドを実行する。
    #
    #@param src             [Hash] 送信元サービスのノード情報
    #@param dst             [Hash] 送信先サービスのノード情報
    #@param app_id          [Hash] パスを一意に選別するためのID(tos or vlan)
    #@param send_conditions [Hash] 送信用パス選定時の条件(bandwidth)
    #@param recv_conditions [Hash] 受信用パス選定時の条件(bandwidth)
    #@return [String] 作成したパスのパスID
    #@raise [NetworkError] ネットワーク構成に障害がある場合
    #@raise [InternalServerError] NCPSサーバー内部でエラーが発生した場合
    #@raise [Timeout::Error] 要求がタイムアウトした場合
    #
    def create_bi_path(src, dst, app_id, send_conditions, recv_conditions)
        result = sync_do{ |callback| super(src, dst, app_id, send_conditions, recv_conditions, callback) }
        return result["path_id"]
    end

    # OFCのパス更新コマンドを実行する。
    #
    #@param [String] path_id 更新するパスのID
    #@param [Hash] conditions パス選定時の条件(bandwidth)
    #@return [void]
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #@raise [InternalServerError] NCPSサーバー内部でエラーが発生した場合
    #@raise [Timeout::Error] 要求がタイムアウトした場合
    #
    def update_path(path_id, conditions)
        sync_do{ |callback| super(path_id, conditions, callback) }
    end

    # OFCの双方向パス削除コマンドを実行する。
    #
    #@param [String] path_id 更新するパスのID
    #@return [void]
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #@raise [InternalServerError] NCPSサーバー内部でエラーが発生した場合
    #@raise [Timeout::Error] 要求がタイムアウトした場合
    #
    def delete_bi_path(path_id)
        sync_do{ |callback| super(path_id, callback) }
    end

    # OFCへ最適化要求を送信する。
    #
    #@raise [InternalServerError] NCPSサーバー内部でエラーが発生した場合
    #@raise [Timeout::Error] 要求がタイムアウトした場合
    #@return [void]
    #
    def optimize()
        sync_do{ |callback| super(callback) }
    end

    # OFCのノード取得コマンドを実行する。
    #
    #@return [Array<Hash>] ノードの一覧
    #@raise [InternalServerError] NCPSサーバー内部でエラーが発生した場合
    #@raise [Timeout::Error] 要求がタイムアウトした場合
    #@todo フラッティングによる検索になってしまうため、他の方式を検討する。
    #
    def get_nodes()
        result = sync_do{ |callback| super(callback) }
        return result["nodes"].collect{ |node| JSON.parse(node) }
    end

    # TCPによるサーバーとの通信を行なう。
    #
    #@param [String] host 送信先ホスト
    #@param [Integer] port 送信先ポート
    #@param [String] payload 送信データ（JSON）
    #@return [void]
    #@raise [Timeout::Error] 要求がタイムアウトした場合
    #
    def send_tcp(host, port, payload)
        timeout(TIMEOUT_TO_SERVER) do
            super(host, port, payload)
        end

    rescue Timeout::Error
        log_warn("send timeout(#{host}, #{port}], #{payload})")
        raise $!
    end

    #@private for debug
    def dump()
        result = sync_do{ |callback| super(callback) }
        return result["topology"], result["routes"]
    end

    private

    # エラー情報をチェックし、例外を送出する。
    #
    #@param [Hash] result 問合せ結果
    #@return [void]
    #@raise [NetworkError] ネットワーク構成に障害がある場合
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #@raise [InternalServerError] NCPSサーバー内部でエラーが発生した場合
    #
    def check_error(result)
        log_trace(result)
        error = result["error"]
        case error
        when 'ERR_CANNOT_GET_PATHID', 'ERR_CANNOT_GET_SCNID'
            raise NetworkError, error

        when 'ERR_INVALID_PATHID'
            raise InvalidIDError, error

        when 'ERR_INTERNAL'
            raise InternalServerError, error
        end
    end

end
