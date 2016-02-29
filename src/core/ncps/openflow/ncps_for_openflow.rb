# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require 'forwardable'

require_relative '../../utility/sync'
require_relative './ncps_server_for_openflow'
require_relative './openflow_connector_sync'
require_relative './openflow_settings'

#= OpenFlowネットワーク向けのNCPS
#
#@@see NCPS
#@author NICT
#
class NCPSForOpenFlow < NCPSInterface
    include OpenflowSettings

    # 初期化処理
    #
    #@param [Hash] opts 起動オプション
    #@option opts [String]  :ip             自ノードのIPアドレス
    #@option opts [Integer] :port           コマンド受信用のポート番号
    #@option opts [String]  :mask           サブネットマスク
    #@option opts [Integer] :cmd_port       コマンドサーバのポート番号
    #@option opts [Integer] :data_port_max  データメッセージ用基底ポート番号
    #@option opts [Integer] :data_port_max  データメッセージ用ポート番号の上限
    #@return [void]
    #
    def initialize(opts = {})
        @connector    = OpenFlowConnectorSync.new("#{opts[:ip]}/#{opts[:mask]}", opts[:cmd_port])
        @default_cond = {
            "priority"  => 100,
            "bandwidth" => 10**7,
        }
        @control_cond = {
            "priority"  => 255,
            "bandwidth" => 10**6,
        }
        @ip_addr       = opts[:ip]
        @app_port_base = opts[:data_port_base]
        @app_port_max  = opts[:data_port_max]

        @server   = NCPSServerForOpenFlow.new(self, opts)
        @paths    = SyncHash.new() {|h, k| h[k] = [] }
        @flows    = SyncHash.new()
        @sessions = SyncHash.new() {|h, k| h[k] = [] }

    end

    #(@see NCPSInterface#start)
    def start()
        middleware_id, service_server_ip = @connector.init(method(:on_violation))
        log_info("Service Server = #{service_server_ip}")

        @server.start_server()

        return middleware_id, service_server_ip
    end

    #(@see NCPSInterface#stop)
    def stop()
        @server.stop_server()
    end

    #(@see NCPSInterface#create_flow)
    def create_flow(path_id, src, dst, condition = @default_cond)
        log_trace(path_id, src, dst, condition)
        log_time()
        # まずデータの待ち受けサーバを立てる。（TOSを使うため必須）
        app_port = @server.request("create_flow_dst", dst, [src])
        if app_port
            begin
                # OFCに経路の登録を依頼する
                flow_id = @connector.create_bi_path(src, dst, app_port, condition, @control_cond)
                @server.request("create_flow_src", src, [path_id, dst, app_port])
            rescue
                @server.send("release_port", dst, [@ip_addr, app_port])
                raise NetworkError, "couldn't create flow: id=#{path_id}, src=#{src}, dst=#{dst}"
            end
        else
            raise NetworkError, "couldn't get app port: id=#{path_id}, src=#{src}, dst=#{dst}"
        end
        @paths[path_id] << {:id => path_id, :src => src, :dst => dst, :port => app_port, :flow => flow_id}

        EventCollector.create_flow(path_id, flow_id)
        log_time()
    end

    #(@see NCPSInterface#delete_flow)
    def delete_flow(path_id, src = nil)
        log_trace(path_id, src)
        log_time()
        paths = @paths[path_id]
        if paths.nil?
            raise InvalidIDError, path_id
        end

        # srcの指定があれば、部分的に消す。（1つのみ該当するはず）
        delete_paths = paths.select{|path| src == nil || src == path[:src]}

        paths -= delete_paths
        delete_paths.each do |path|
            log_time()
            begin
                @connector.delete_bi_path(path[:flow])
            rescue
                log_warn($!)
            end
            log_time()
            @server.send("delete_flow_src", path[:src], [path_id])
            @server.send("delete_flow_dst", path[:dst], [path[:src], path[:port]])
            EventCollector.delete_flow(path_id, path[:flow])
            log_time()
        end
        log_time()
    end

    #(@see NCPSInterface#update_flow)
    def update_flow(path_id, condition)
        log_trace(path_id, condition)
        paths = @paths[path_id]
        if paths.nil?
            raise InvalidIDError, path_id
        end

        paths.each do |path|
            @connector.update_path(path[:flow], condition, @control_cond)
            EventCollector.update_flow(path_id, path[:flow])
        end
    end

    #(@see NCPSInterface#send_data)
    def send_data(path_id, data, data_size, sync = false)
        log_trace(path_id, data, data_size, sync)
        flow = @flows[path_id]
        if flow.nil?
            raise InvalidIDError, path_id
        end

        if sync
            @server.request_by_tos("receive_data", flow[:dst], flow[:port], [path_id, data, data_size])
        else
            @server.send_by_tos("receive_data", flow[:dst], flow[:port], [path_id, data, data_size])
        end
    end

    #(@see NCPSInterface#request)
    def request(dst, message)
        log_trace(dst)
        return @server.request("receive_request", dst, [message])
    end

    #(@see NCPSInterface#propagate)
    def propagate(dsts, message)
        log_trace(dsts)
        dsts.each do |dst|
            @server.send("receive_propagate", dst, [message])
        end
    end

    private

    # NCPSサーバーからのVaioration通知を受け取る
    #
    def on_violation(name, payload)
        log_trace(name, payload)
        log_debug() {"name = #{name}, payload = #{payload}"}
        if name == 'OPTIMIZE_FAILURE'
            path_ids = []
            payload["routes"].each do |flow_id|
                # Openflow DriverからはFlowIDの片側の数字しか返ってこない。
                @paths.values.each do |paths|
                    paths.each do |path| 
                        if path[:flow] =~ /^#{flow_id}_/
                            path_ids << path[:id]
                        end
                    end
                end
            end
            notify_violation(path_ids)
        end
    end

    # データ送信側ノードにフローを書き込む
    #
    def create_flow_src(path_id, dst, app_port)
        log_trace(path_id, dst)
        @flows[path_id] = {:dst => dst, :port => app_port}
    end

    # データ受信サーバの起動。
    # フローの受信側ノードで実施する。
    # SCNでは、パケットのTOSによる経路制御を行なう。
    #
    def create_flow_dst(src)
        toses = @sessions[src]
        log_debug() {"src = #{src}, toses = #{toses}"}

        # 同じTOS番号の一番若い番号を取得
        for port in @app_port_base...(@app_port_base + TOS_SIZE)
            tos = to_tos(port)
            next if tos == 0    # tos=0はコントロール用パス
            next if toses.include?(tos)

            while (port <= @app_port_max)
                begin
                    @server.start_app_server(port)    #try&errorで先ポートを探す
                    toses << tos
                    return port

                rescue
                    log_warn("port #{port}: #{$!}")
                end
                port += TOS_SIZE     #同じTOS番号の別のポートを探す
            end
        end
        return nil
    end

    # データ送信側ノードからフローを削除する。
    #
    def delete_flow_src(path_id)
        log_trace(path_id)
        @flows.delete(path_id)
    end

    # データ受信サーバの終了。
    # フローの受信側ノードで実施する。
    #
    def delete_flow_dst(src, port)
        log_trace(src, port)
        toses = @sessions[src]
        toses.delete(to_tos(port))
        @server.stop_app_server(port)
    rescue
        log_warn("port #{path[:port]}: #{$!}")
    end
end
