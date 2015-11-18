#-*- coding: utf-8 -*-
require 'eventmachine'
require 'socket'
require 'ipaddr'
require 'logger'
require 'json'

require_relative '../../utils'
require_relative '../../utility/semaphore'
require_relative './openflow_server'
require_relative './openflow_settings'

#= OpenFlowネットワーク向けの通信ライブラリ
#@author NICT
#
class OpenFlowConnector
    include OpenflowSettings

    #@param [String] ip 自身のIPアドレス
    #@param [Integer] cmd_port OFCからの通信待ち受けポート番号
    #
    def initialize(ip, cmd_port)
        if ip.include? "/"
            ip, @mask = ip.split("/")
        end
        @my_ip       = ip
        @cmd_port    = cmd_port
        @id          = 0
        @on_response = Hash.new()
    end

    # OFCとの接続を実施。自IPからゲートウェイを選定する。
    #
    #@param [Callable] on_init 初期化完了時呼出コールバック
    #@param [Callable] on_push OFCからのPUSH通知呼出コールバック
    #@return [Thread] サーバーからの通信を待ち受けるスレッド
    #
    def init(on_init, on_push = nil)
        register_on_response(PUSH_KEY, on_push)
        if @cmd_server_thread.nil? or not @cmd_server_thread.alive?
            @cmd_server_thread = Thread.new do
                EM.run do
                    begin
                        EM.start_server("0.0.0.0", @cmd_port, OpenflowServer) do |conn|
                            conn.on_response = @on_response
                        end
                    rescue
                        log_error("start ofc server to faild" ,$!)
                    end
                end
            end
        end
        connect_ofc(on_init)

        return @cmd_server_thread
    end

    # OFCのパス作成コマンドを実行する。
    #
    #@param [Hash] src 送信元サービスのノード情報
    #@param [Hash] dst 送信先サービスのノード情報
    #@param [Hash] app_id パスを一意に選別するためのID(tos or vlan)
    #@param [Hash] conditions パス選定時の条件(bandwidth)
    #@param [Callable] on_response パス生成完了時のコールバック
    #@return [void]
    #
    def create_bi_path(src, dst, app_id, send_conditions, recv_conditions, on_response = nil)
        req_id = get_id
        json_str = JSON.dump({
            "NAME" => "CREATE_BI_PATH_REQUEST",
            "timestamp" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
            "req_id" => req_id,
            "src" => {"ipaddr" => src},
            "dst" => {"ipaddr" => dst},
            "app_id" => {"tos" => to_tos(app_id) },
            "send_conditions" => send_conditions,
            "recv_conditions" => recv_conditions,
            "listen_peer" => {
            "ipaddr" => @my_ip,
            "port" => @cmd_port
            },
        })
        register_on_response(req_id, on_response)
        send_tcp(@gw_peer.ipaddr, @gw_peer.port, json_str)
    end

    # OFCのパス更新コマンドを実行する。
    #
    #@param [String] path_id 更新対象のパスID
    #@param [Hash] conditions パス選定時の条件(bandwidth)
    #@param [Callable] on_response パス生成完了時のコールバック
    #@return [void]
    #
    def update_path(path_id, conditions, on_response = nil)
        req_id = get_id
        json_str = JSON.dump({
            "NAME" => "UPDATE_PATH_REQUEST",
            "timestamp" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
            "req_id" => req_id,
            "path_id" => path_id,
            "conditions" => conditions,
            "listen_peer" => {
            "ipaddr" => @my_ip,
            "port" => @cmd_port
            }
        })
        register_on_response(req_id, on_response)
        send_tcp(@gw_peer.ipaddr, @gw_peer.port, json_str)
    end

    # OFCのパス削除コマンドを実行する。
    #
    #@param [String] path_id 削除対象のパスID
    #@param [Callable] on_response パス生成完了時のコールバック
    #@return [void]
    #
    def delete_bi_path(path_id, on_response = nil)
        req_id = get_id
        json_str = JSON.dump({
            "NAME" => "DELETE_BI_PATH_REQUEST",
            "timestamp" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
            "req_id" => req_id,
            "path_id" => path_id,
            "listen_peer" => {
            "ipaddr" => @my_ip,
            "port" => @cmd_port
            }
        })
        register_on_response(req_id, on_response)
        send_tcp(@gw_peer.ipaddr, @gw_peer.port, json_str)
    end

    # OFCへ最適化要求を送信する。
    #
    #@param [Callable] on_response パス生成完了時のコールバック
    #@return [void]
    #
    def optimize(on_response = nil)
        req_id = get_id
        json_str = JSON.dump({
            "NAME" => "OPTIMIZE_REQUEST",
            "timestamp" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
            "req_id" => req_id,
            "listen_peer" => {
            "ipaddr" => @my_ip,
            "port" => @cmd_port
            }
        })
        register_on_response(req_id, on_response)
        send_tcp(@gw_peer.ipaddr, @gw_peer.port, json_str)
    end

    #@private for debug
    def dump(on_response = nil)
        req_id = get_id
        json_str = JSON.dump({
            "NAME" => "DUMP_REQUEST",
            "timestamp" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
            "req_id" => req_id,
            "listen_peer" => {
            "ipaddr" => @my_ip,
            "port" => @cmd_port
            }
        })
        register_on_response(req_id, on_response)
        send_tcp(@gw_peer.ipaddr, @gw_peer.port, json_str)
    end

    # OFCのノード取得コマンドを実行する。
    #
    #@param [Callable] on_response パス生成完了時のコールバック
    #@return [void]
    #@todo OFCによる集中管理になってしまうため、ほかの方法を模索する
    #
    def get_nodes(on_response = nil)
        req_id = get_id
        json_str = JSON.dump({
            "NAME" => "GET_NODES_REQUEST",
            "timestamp" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
            "req_id" => req_id,
            "listen_peer" => {
            "ipaddr" => @my_ip,
            "port" => @cmd_port
            },
        })
        register_on_response(req_id, on_response)
        send_tcp(@gw_peer.ipaddr, @gw_peer.port, json_str)
    end

    # UDP送信
    #
    #@param [String] host 送信先ホスト
    #@param [Integer] port 送信先ポート
    #@param payload 送信データ
    #@return [void]
    #
    def send_broadcast(host, port, payload)
        udp = UDPSocket.open()
        sockaddr = Socket.pack_sockaddr_in(port, host)
        udp.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
        udp.send(payload, 0, sockaddr)
    end

    # UDP送信
    #
    #@param [String] host 送信先ホスト
    #@param [Integer] port 送信先ポート
    #@param payload 送信データ
    #@return [void]
    #
    def send_udp(host, port, payload)
        log_debug() {"[ctrl] send_udp(#{host}, #{port}], #{payload})"}

        log_time()
        udp = UDPSocket.open()
        sockaddr = Socket.pack_sockaddr_in(55555, host)
        #udp.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
        udp.send(payload, 0, sockaddr)
        log_time()
    end

    # OpenFlowサーバーとの接続を確立する。
    # 接続要求はブロードキャストで行い、返答を待つ。
    #
    #@param [Callable] on_init 通信確立後のコールバック
    #
    # TCP送信
    #
    #@param [String] host 送信先ホスト
    #@param [Integer] port 送信先ポート
    #@param payload 送信データ
    #@return [void]
    #
    def send_tcp(host, port, payload)
        payload << SEPARTOR
        log_debug() {"[ctrl] send_tcp(#{host}, #{port}], #{payload})"}

        log_time()
        sock = TCPSocket.open(host, port)
        log_time()
        sock.write(payload)
        sock.close()
    end

    # OpenFlowサーバーとの接続を確立する。
    # 接続要求はブロードキャストで行い、返答を待つ。
    #
    #@param [Callable] on_init 通信確立後のコールバック
    #@return [void]
    #
    def connect_ofc(on_init)
        bcastIp = get_broadcast(@my_ip, @mask)
        log_debug() {"bcast Ip = #{bcastIp}"}
        req_id = get_id
        json_str = JSON.dump({
            "NAME" => "INITIALIZE_REQUEST",
            "timestamp" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
            "req_id" => req_id,
            "listen_peer" => {
            "ipaddr" => @my_ip,
            "port" => @cmd_port,
            "protocol" => "TCP"
            }
        })
        register_on_response(req_id, Proc.new{|resp|
            log_trace
            @gw_peer = Peer.from_json(resp["gw_peer"])
            log_debug() {"gw : #{@gw_peer}"}
            on_init.call(resp, self)
            start_heart_beat() if $config[:use_heart_beat]
            log_trace
        })
        send_broadcast(bcastIp, BROAD_CAST_PORT, json_str)
    end

    #    private

    # ゲートウェイアドレス取得
    #
    def get_broadcast(ip, mask)
        if mask
            ipaddr = IPAddr.new(ip + "/" + mask)
            baddr = ipaddr | (~ipaddr.instance_variable_get(:@mask_addr) & IPAddr::IN4MASK)
            baddr.to_s()
        else
            "255.255.255.255"
        end
    end

    # 一意なリクエスト用のIDを取得する。
    #
    def get_id
        return @id += 1
    end

    # リクエストのコールバックを登録する。。
    #
    def register_on_response(id, on_response = nil)
        log_trace(id, on_response)
        if not on_response.nil?
            @on_response[id] = on_response
        end
    end

    # OFCによるノード死活監視を行う際のHEART BEATメッセージ
    #
    def start_heart_beat()
        Thread.new do
            loop do
                sleep($config[:heart_beat_interval])

                json_str = JSON.dump({
                    "NAME" => "HEART_BEAT_REQUEST",
                    "timestamp" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
                    "req_id" => 0,
                    "listen_peer" => {
                    "ipaddr" => @my_ip,
                    "port" => @cmd_port
                    },
                })
                begin
                    send_udp(@gw_peer.ipaddr, @gw_peer.port, json_str)
                rescue
                    # do nothing.
                rescue Timeout::Error
                    # do nothing.
                end
            end
        end
    end
end
