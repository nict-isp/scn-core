# -*- coding: utf-8 -*-
require_relative './utils'
require_relative './utility/collector'
require_relative './translator/supervisor'
require_relative './translator/stats'
require_relative './ncps/ncps'
require_relative './app_if'
require_relative './dsn/dsn_executor'
require_relative './dsn/dsn_creator'
require_relative './dsn/event_manager'
require_relative './dsn/processing_manager'

#= SCNミドルウェアのメインクラス
# SCNミドルウェアのプロセス本体。
#
#@author NICT
#
class SCNManager

    def initialize()
        @rpc_initial_rx_port = $config[:rpc_initial_rx_port]
    end

    # SCNミドルウェアの参加通知を行い、各種初期設定を行う。
    #
    #@param [String] ip 自ノードのIPアドレス
    #@param [Integer] mask ネットマスク
    #@param [String] default_id デフォルトのミドルウェアID（テスト時のみ指定する）
    #@return [void]
    #
    def setup(ip, mask, default_id=nil)
        log_trace(ip, mask, default_id)

        EventCollector.setup()
        NCPS.create($ncps_network, {
            :ip             => ip,
            :mask           => mask,
            :port           => $config[:ctrl_port],
            :data_port_base => $config[:data_port_base],
            :data_port_max  => $config[:data_port_max],
            :cmd_port       => $config[:cmd_port],
            :stdin          => $stdin,
            :request_slice  => $config[:request_slice],
        })
        # NCPS へミドルウェアの起動を通知する。
        begin
            @middleware_id, service_server = NCPS.start()
            if not default_id.nil?()
                @middleware_id = default_id
            end
            log_info("middleware ID(=#{@middleware_id}) is registerd successfully.")

            #rescue NetworkError, InternalServerError, Timeout::Error
        rescue
            log_warn("can not connect to NCPS Server. retry to connect NCPS Server.")
            sleep(1)
            retry
        end

        Stats.start($config[:statistics_interval])
        Supervisor.setup(@middleware_id, service_server)
        DSNExecutor.setup(@middleware_id, $config[:dsn_observe_interval], $config[:dsn_auto_execute_interval])
    end

    #  RPCサーバを起動する。
    #
    #@return [void]
    #
    def start()
        log_trace()

        scn_rpc_server = SCNManagerRPCServer.new()
        scn_rpc_server.start()

        puts "'SCN middleware' started."
        log_info("SCN Manager start.")
        log_debug() {"RPC receive server start. (RPC RX port = #{@rpc_initial_rx_port})"}

        @rpc_server = MessagePack::RPC::Server.new
        @rpc_server.listen("0.0.0.0", @rpc_initial_rx_port, scn_rpc_server)
        @rpc_server.run
    end

    # SCNミドルウェアの離脱通知を行い、各種スレッドを停止する。
    #
    #@return [void]
    #@todo 停止処理を実装する。
    #
    def stop()
        log_trace()

        begin
            NCPS.stop()
        rescue
            # 例外が発生しても無視して処理を継続する。
        end
        log_info("middleware ID(=#{@middleware_id}) is unregisterd.")
    end
end

#= Applicationとの初期通信用RPCサーバクラス
#  Applicationからの最初の接続を受け付けるRPCサーバ。
#
#@author NICT
#
class SCNManagerRPCServer

    def initialize()
        @rpc_rx_port       = $config[:rpc_rx_port]
        @rpc_tx_port_base  = $config[:rpc_tx_port_base]
        @rpc_ip_address    = $config[:rpc_ip_address]

        @application_rpc = ApplicationRPC.new(@rpc_rx_port, @rpc_ip_address)
        @application_count = 1
    end

    # Applicationサーバーを起動する。
    #
    def start()
        @application_rpc.start()
    end

    # ApplicationとのRPC用サーバを開始し、Application側の受信ポートを通知する。
    #
    #@return [Array]
    #  (Integer) Application側の送信ポート、
    #  (Integer) Application側の受信ポート
    #
    def connect_app()
        log_trace()

        rpc_tx_port = get_rpc_tx_port()
        log_info("RPC TX port = #{rpc_tx_port}")

        # SCN側の受信ポートがアプリケーション側の送信ポート、
        # SCN側の送信ポートがアプリケーション側の受信ポートになる。
        return @rpc_rx_port, rpc_tx_port
    end

    private

    # SCN側の送信ポート番号発行メソッド
    #
    #@return [Integer] SCN側の送信ポート
    #
    def get_rpc_tx_port()
        rpc_tx_port = @rpc_tx_port_base + @application_count
        @application_count += 1

        return rpc_tx_port
    end
end

