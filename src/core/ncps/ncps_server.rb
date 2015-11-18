# -*- coding: utf-8 -*-
require 'msgpack'

require_relative './request'

#= NCPSクライアントの通信サーバクラス
# NCPSクライアント層のノード間通信を行なう。
#
#@author NICT
#
class NCPSServer

    #@param [NCPS] client NCPSのインスタンス
    #@param [Hash] opts 起動オプション
    #@option opts [String]  :ip             自ノードのIPアドレス
    #@option opts [Integer] :port           コマンド待受け用ポート
    #@return [void]
    #
    def initialize(client, opts = {})
        @client        = client
        @self_addr     = opts[:ip]
        @ctrl_port     = opts[:port]
        @signatures    = {}
        @request       = Request.new()
    end

    # サーバを開始する。
    #
    #@return [void]
    #
    def start_server()
        Thread.new() do
            EventMachine.run do
                signature = EventMachine::start_server(@self_addr, @ctrl_port, NCPSServerConnection, @client)
                @signatures[@ctrl_port] = signature
            end
        end
    end

    # サーバを終了する。
    #
    #@return [void]
    #
    def stop_server()
        for signature in @signatures.values()
            EventMachine::stop_server(signature)
        end
        @signatures.clear()
    end

    # レスポンスを伴う制御メッセージを複数送信する
    #
    #@param [String] method_name 呼出メソッド
    #@param [Array] param 呼出メソッドの実行先と引数のペアの配列
    #@return [void]
    #
    def requests(method_name, params)
        return @request.get_results(params.size()) { |request_id|
            EventMachine::schedule do
                for addr, arguments in params
                    EventMachine::connect(addr, @ctrl_port, NCPSClientConnection,
                    method_name, arguments, @request, request_id)
                end
            end
        }
    end

    # レスポンスを伴う制御メッセージを送信する
    #
    #@param [String] method_name 呼出メソッド
    #@param [String] addr 呼出メソッドの実行先
    #@param [Array] arguments 呼出メソッドの引数
    #@return [void]
    #
    def request(method_name, addr, arguments=[])
        return @request.get_result { |request_id|
            EventMachine::schedule do
                EventMachine::connect(addr, @ctrl_port, NCPSClientConnection,
                method_name, arguments, @request, request_id)
            end
        }
    end

    # レスポンスを伴わない制御メッセージを送信する
    #
    #@param [String] method_name 呼出メソッド
    #@param [String] addr 呼出メソッドの実行先
    #@param [Array] arguments 呼出メソッドの引数
    #@return [void]
    #
    def send(method_name, addr, arguments=[])
        EventMachine::schedule do
            EventMachine::connect(addr, @ctrl_port, NCPSClientConnection,
            method_name, arguments)
        end
    end
end

#= NCPSクライアントのコネクションクラス
# EventMachineでの通信に使用する。
# MTUで分割されるパケットを結合する。
#
#@author NICT
#
module NCPSConnection

    def initialize()
        @rcvbuf = ""    # 受信データ格納先
        @size = nil
    end

    #@param [Object] data 送信データ
    #@return [Binary] バイナリ化した送信データ（効率的な復元のため、データサイズを付与）
    #
    def to_msgpack(data)
        data = data.to_msgpack
        data.insert(0, sprintf("%012d", data.length))
    end

    # 受信データを結合し、receive_data_performedを呼び出す。
    #
    #@param [Binary] data 受信データ
    #
    def receive_data(data)
        @rcvbuf << data

        begin
            if @size.nil?
                if @rcvbuf.length >= 12
                    @size = @rcvbuf.slice!(0, 12).to_i
                end
            end

            unless @size.nil?
                if @rcvbuf.length == @size
                    receive_data_performed()

                elsif @rcvbuf.length > @size
                    trunc = @rcvbuf.slice!(@size)
                    receive_data_performed()
                end
            end
        rescue
            # エラーでサーバが終了しないように
            puts "Problem receiving : #{$!}"
        end
    end
end

#= 通信サーバ側コネクションクラス
#
#@author NICT
#
module NCPSServerConnection
    include NCPSConnection

    #@param [NCPSProtocol] protocol 受信メッセージの通知先
    #
    def initialize(protocol)
        @protocol = protocol
        super()
    end

    # 要求のあったメソッドを実行する。
    # レスポンスがあれば、呼出元に
    #
    #@return [void]
    #
    def receive_data_performed
        EventMachine.defer(proc do
            method_name, arguments = MessagePack.unpack(@rcvbuf)
            log_trace(method_name, arguments)
            @protocol.method(method_name).call(*arguments)

        end, proc do |result|
            log_trace(result)
            send_data(to_msgpack(result))
            close_connection_after_writing
        end)
    end
end

#= 制御メッセージ通信クライアント側コネクションクラス
#
#@author NICT
#
module NCPSClientConnection
    include NCPSConnection

    #@param [String] method_name 呼出先のメソッド名
    #@param [Object] arguments 呼出時のパラメータ
    #@param [Request] request 同期用のリクエストクラス
    #@param [Integer] request_id リクエスト番号
    #
    def initialize(method_name, arguments, request = nil, request_id = 0)
        log_trace(method_name, arguments, request, request_id)
        @payload    = [method_name, arguments]
        @request    = request
        @request_id = request_id
        super()
    end

    # コネクション確立時にメッセージを送信する。
    #
    #@return [void]
    #
    def post_init
        send_data(to_msgpack(@payload))
    end

    # 呼出先のメソッドからのレスポンスがあれば通知する。
    #
    #@return [void]
    #
    def receive_data_performed
        data = MessagePack.unpack(@rcvbuf)
        log_debug {data}
        unless @request.nil?
            @request.response(@request_id, data)
        end
    end
end

