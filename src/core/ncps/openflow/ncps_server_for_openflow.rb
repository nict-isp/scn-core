# -*- coding: utf-8 -*-
require_relative '../ncps_server'
require_relative './openflow_settings'

#= NCPSクライアントの通信サーバクラス
# NCPSクライアント層のノード間通信を行なう。
#
#@author NICT
#
class NCPSServerForOpenFlow < NCPSServer
    include OpenflowSettings

    # データの受信を開始する。
    # 指定されたポート番号からTOS番号を導出する。
    #
    #@param [Integer] port ポート番号
    #@return [void]
    #
    def start_app_server(port)
        tos = to_tos(port)
        signature = EventMachine::start_serverTos(@self_addr, port, tos, NCPSServerConnection, @client)
        @signatures[port] = signature
    end

    # データの受信を終了する。
    #
    #@param [Integer] port ポート番号
    #@return [void]
    #
    def stop_app_server(port)
        signature = @signatures.delete(port)
        if not signature.nil?
            EventMachine::stop_server(signature)
        end
    end

    # データを送信する。（非同期）
    #
    #@param [String] addr データの送信先
    #@param [Integer] port データの待受けポート
    #@param [Array] arguments 送信データ
    #@return [void]
    #
    def send_by_tos(method_name, addr, port, arguments)
        EventMachine::schedule do
            EventMachine::connectTos(addr, port, to_tos(port), NCPSClientConnection,
            method_name, arguments)
        end
    end

    # データを送信する。（同期）
    #
    #@param [String] addr データの送信先
    #@param [Integer] port データの待受けポート
    #@param [Array] arguments 送信データ
    #@return [void]
    #
    def request_by_tos(method_name, addr, port, arguments=[])
        @request.get_result { |request_id|
            EventMachine::schedule do
                EventMachine::connectTos(addr, port, to_tos(port), NCPSClientConnection,
                method_name, arguments, @request, request_id)
            end
        }
    end
end
