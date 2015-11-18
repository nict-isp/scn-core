# -*- coding: utf-8 -*-
require 'json'
require 'msgpack/rpc'
require 'singleton'
require_relative './utils'
require_relative './utility/validator'

#= ApplicationとのRPCを管理するクラス
#
# RPCのためのポートやIPアドレスを管理し、RPC用サーバ/クライアントを生成する。
#
#@author NICT
#
class ApplicationRPC

    # 初期設定
    #
    #@param [Integer] rpc_rx_port RPC受信用ポート
    #@param [Integer] rpc_ip_address RPC送信IPアドレス
    #@return [void]
    #
    def initialize(rpc_rx_port, rpc_ip_address)
        log_trace(rpc_rx_port, rpc_ip_address)
        @rpc_rx_port    = rpc_rx_port
        @rpc_ip_address = rpc_ip_address

        ApplicationRPCClient.setup(@rpc_ip_address)
    end

    # ApplicationとのRPCサーバ/クライアントを生成する
    #
    #@return [void]
    #
    def start()
        log_trace()
        Thread.new do
            begin
                log_debug() {"RPC receive server start. RX port = #{@rpc_rx_port}"}
                @rpc_server = MessagePack::RPC::Server.new
                @rpc_server.listen("0.0.0.0", @rpc_rx_port, ApplicationRPCServer.instance)
                @rpc_server.run

            ensure
                log_error() {"RPC receive server stop."}
            end
        end
    end
end

#= ApplicationとのAPI用RPCサーバクラス
#
# ApplicationからRPC経由でコールされるメソッドを定義する。
#
#@author NICT
#
class ApplicationRPCServer
    include Singleton

    # サービス参加API
    #
    #@param [String] service_name サービス名
    #@param [Hash] service_info サービスの情報
    #@param [Integer] port サービスの受信ポート番号
    #@return [String] サービスID
    #@raise [ArgumentError] サービス情報の形式が誤っている。
    #
    def join_service(service_name, service_info, port)
        log_trace(service_name, service_info, port)
        log_time()
        Validator.service_info(service_info)
        service_id = Supervisor.join_service(service_name, service_info, port)

        log_info("service name(=#{service_name}) was joined successfully. (service ID =#{service_id})")

        log_time()
        return service_id

    rescue Exception
        log_error("service name(=#{service_name}) failed to join.", $!)
        raise ApplicationError, $!
    end

    # サービス情報変更API
    #
    #@param [String] service_id サービスID
    #@param [Hash] service_info サービスの情報
    #@return [void]
    #@raise [ArgumentError] 存在しないサービスIDが指定された。/ サービス情報の形式が誤っている。
    #@raise [Timeout::Error] ノード間通信でタイムアウトが発生した。
    #
    def update_service(service_id, service_info)
        log_trace(service_id, service_info)
        log_time()        
        Validator.service_info(service_info)

        Supervisor.update_service(service_id, service_info)

        log_info("service ID(=#{service_id}) was updated successfully. (info = #{service_info})")
        log_time()

    rescue Exception
        log_error("service ID(=#{service_id}) failed to update.", $!)
        raise ApplicationError, $!
    end

    # サービス離脱API
    #
    #@param [String] service_id サービスID
    #@return [void]
    #@raise [ArgumentError] 存在しないサービスIDが指定された。
    #@raise [Timeout::Error] ノード間通信でタイムアウトが発生した。
    #
    def leave_service(service_id)
        log_trace(service_id)
        log_time()
        Supervisor.leave_service(service_id)

        log_info("service ID(=#{service_id}) was leaved successfully.")
        log_time()

    rescue Exception
        log_error("service ID(=#{service_id}) failed to leave.", $!)
        raise ApplicationError, $!
    end

    # データ送信API
    #
    #@param [String] service_id サービスID
    #@param [String/Hash] data 送信データ
    #@param [Integer] data_size 送信データサイズ
    #@param [String] channel_id チャネルID
    #@param [Boolean] sync Trueの時、送信の完了を待ち合せる
    #@return [JSON] 送信したチャネルの配列
    #@raise [ArgumentError] 存在しないチャネルIDが指定された / データフォーマットが異常
    #@raise [Timeout::Error] 要求がタイムアウトした場合
    #
    def send_data(service_id, data, data_size, channel_id, sync)
        log_trace(service_id, data_size, channel_id, sync)
        log_time()
        corrected_data = correction_data(data)
        channel_id_list = Supervisor.send_data(service_id, corrected_data, data_size, channel_id, sync)
        log_time()

        json = JSON.dump(channel_id_list)
        log_debug() {"channel ID list = \"#{json}\""}

        log_time()
        return json

    rescue Exception
        log_error("data(#{data_size} bytes) failed to send.", $!)
        raise ApplicationError, $!
    end

    # DSN生成API
    # Event Data Modelから、DSN記述を生成する。
    #@param [String] table_name テーブル名
    #@param [Hash] event_data_model Event Data Model
    #@retrun [String] 生成したDSN記述。
    #@raise [ArgumentError] Event Data Modelのフォーマットが不適切
    #
    def create_dsn(table_name, event_data_model)
        log_trace(table_name, event_data_model)
        log_time()
        # DSN記述生成処理
        dsn_desc, overlay_name = DSNCreator.create_dsn(table_name, event_data_model)
        log_time()
        log_debug() {"overlay_name = #{overlay_name}, dsn desc = #{dsn_desc}"}

        return overlay_name, dsn_desc

    rescue Exception
        log_error("failed to create DSN.", $!)
        raise ApplicationError, $!
    end

    # オーバーレイ生成API
    #
    #@param [String] overlay_name オーバーレイ名
    #@param [String] dsn_desc DSN記述
    #@param [Integer] port メッセージ受信ポート
    #@retrun [String] オーバーレイID
    #
    def create_overlay(overlay_name, dsn_desc, port)
        log_trace(overlay_name, dsn_desc, port)
        log_time()
        overlay_id = Supervisor.create_overlay(overlay_name, port)
        DSNExecutor.add_dsn(overlay_id, dsn_desc)

        log_debug() {"overlay(#{overlay_name}) has been created successfully. (id = #{overlay_id})"}
        log_time()

        return overlay_id

    rescue Exception
        log_error("failed to create overlay.", $!)
        Supervisor.delete_overlay(overlay_id)
        raise ApplicationError, $!
    end

    # オーバーレイ削除API
    #
    #@param [String] overlay_id オーバーレイID
    #
    def delete_overlay(overlay_id)
        log_trace(overlay_id)
        log_time()
        DSNExecutor.delete_dsn(overlay_id)
        Supervisor.delete_overlay(overlay_id)

        log_debug() {"overlay(#{overlay_id}) has been deleted successfully."}
        log_time()

    rescue Exception
        log_error("failed to delete overlay.", $!)
        raise ApplicationError, $!
    end

    # オーバーレイ変更API
    #
    #@param [String] overlay_name オーバーレイ名
    #@param [String] overlay_id オーバーレイID
    #@param [String] dsn_desc DSN記述
    #
    def modify_overlay(overlay_name, overlay_id, dsn_desc)
        log_trace(overlay_name, overlay_id, dsn_desc)
        log_time()
        DSNExecutor.modify_dsn(overlay_id, dsn_desc)

        log_debug() {"overlay(#{overlay_id}) has been modified successfully."}
        log_time()

    rescue Exception
        log_error("failed to modify overlay.", $!)
        raise ApplicationError, $!
    end

    # チャネル取得API
    #
    #@param [String] channel_id チャネルID
    #@return [JSON] チャネル
    #
    def get_channel(channel_id)
        log_trace(channel_id)
        log_time()
        channel = Supervisor.get_channel(channel_id)
        if channel.nil?
            raise InvalidIDError, "channel not found"
        end

        app_req = channel.channel_req["app_req"]
        channel_info = {
            "id"      => app_req["id"],
            "channel" => app_req["channel"]["meta"],
            "scratch" => app_req["scratch"]["meta"],
            "qos"     => app_req["qos"],
        }
        json = JSON.dump(channel_info)
        log_debug() {"channel = \"#{json}\""}
        log_time()

        return json

    rescue Exception
        log_error("get channel failed.", $!)
        raise ApplicationError, $!
    end

    private

    def correction_data(data)
        if data.instance_of? String
            begin
                corrected_data = JSON.load(data)
            rescue
                raise ArgumentError, "data format is invalid. data is not in JSON format."
            end

        elsif data.instance_of? Array
            corrected_data = data

        elsif data.instance_of? Hash
            corrected_data = [data]
        else
            raise ArgumentError, "data format is invalid. data type = #{data.class}"
        end

        return corrected_data
    end

    # インスタンスメソッドをクラスに委譲
    class << self
        extend Forwardable
        def_delegators :instance, *ApplicationRPCServer.instance_methods(false)
    end
end

#= ApplicationとのAPI用RPCクライアントクラス
#
# RPC経由でコールするApplicationのメソッドを定義する。
#
#@author NICT
#
class ApplicationRPCClient
    include Singleton

    def initialize()
        @message_log_dir = ""
    end

    # 初期設定
    #
    #@param [String] rpc_ip_address RPC送信IPアドレス
    #@return [void]
    #
    def setup(rpc_ip_address)
        log_trace(rpc_ip_address)
        @rpc_ip_address = rpc_ip_address
    end

    # データ受信API
    #
    #@param [String/Hash] data 受信データ
    #@param [Integer] data_size 受信データサイズ
    #@param [String] channel_id チャネルID
    #@param [Integer] rpc_tx_port RPC用送信ポート
    #@return [void]
    #
    def receive_data(data, data_size, channel_id, rpc_tx_port)
        log_trace(data, data_size, channel_id, rpc_tx_port)
        log_time()
        log_info("data(#{data_size} bytes) received. (channel ID = #{channel_id})")

        log_time()
        client = MessagePack::RPC::Client.new(@rpc_ip_address, rpc_tx_port)
        client.timeout = 60
        client.call(:receive_data, data, data_size, channel_id)
        log_time()
        client.close

        log_time()
    rescue Exception
        log_error("receive_data() RPC connection error. RPC tx port = #{rpc_tx_port}", $!)
    end

    # メッセージ受信API
    #
    #@param [String] overlay_id メッセージを受信したオーバーレイID
    #@param [String] message メッセージ
    #@param [Integer] rpc_tx_port RPC用送信ポート
    #@param [Proc] rpc_tx_port 自動実行処理ログ出力コールバック
    #@return [void]
    #
    def receive_message(overlay_id, message, rpc_tx_port)
        log_trace(overlay_id, message, rpc_tx_port)
        log_time()        
        log_info("message received. (overlay id = #{overlay_id})")

        if rpc_tx_port.nil?
            DSNAutoExecutor.log_auto_execute_message(overlay_id, message)
        else
            log_time()
            client = MessagePack::RPC::Client.new(@rpc_ip_address, rpc_tx_port)
            client.timeout = 60
            client.call(:receive_message, overlay_id, message)
            log_time()
            client.close
        end

    rescue Exception
        log_error("receive_message() RPC connection error. RPC tx port = #{rpc_tx_port}", $!)
    end

    # インスタンスメソッドをクラスに委譲
    class << self
        extend Forwardable
        def_delegators :instance, *ApplicationRPCClient.instance_methods(false)
    end
end

