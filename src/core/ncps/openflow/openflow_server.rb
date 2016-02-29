#-*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require 'eventmachine'

require_relative '../../utils'
require_relative './openflow_settings'

#= OpenFlowコントローラからのコマンド受信用サーバ
#@author NICT
#
class OpenflowServer < EM::Connection
    include OpenflowSettings

    # @return [Hash{String=>Callable}] 受信時のコールバックを登録したハッシュ
    attr_accessor :on_response

    def initialize(*args)
        super
        @buffer = ""
        @prev = ""
    end

    # データ受信時処理
    # パケット単位に分割された受信データを結合し、{#receive_data_performed}を呼び出す。
    #
    #@param [String] data 受信データ
    #@return [void]
    #
    def receive_data(data)
        log_trace(data)
        @buffer << data
        @prev << data
        if @prev =~ /\\r\\n\\r\\n/ then
            terminus = @buffer =~ /\\r\\n\\r\\n$/
            data_list = @buffer.split(/\\r\\n\\r\\n/)
            data_list.each_with_index {|splited, index|
                if terminus or index < data_list.length - 1
                    receive_data_performed(splited)
                end
            }
            if not terminus.nil?()
                @buffer = ""
                @prev = ""
            else
                @buffer = data_list[-1]
                @prev = data_list[-1]
            end
        else
            @prev = data
        end
    rescue
        # データ待受けのスレッドが死なないよう、例外はログ出力で握りつぶす。
        log_error("exception in receive_data.", $!)
    end

    # 受信したリクエストキーに対応するハンドラをコールする。
    #
    #@param [String] data JSON形式のコマンドメッセージ
    #@return [void]
    #
    def receive_data_performed(data)
        log_trace(data)
        log_debug() {"recieve_data = #{data}"}
        hash = JSON.parse(data)

        req_id = hash["req_id"]
        if not req_id.nil?
            log_debug() {"req_id = #{req_id}"}
            log_debug() {"callbacks = #{@on_response}"}
            on_response = @on_response[req_id]
            if not on_response.nil?
                on_response.call(hash, req_id)
                log_debug() {"after onResponse: reqid = #{req_id}"}
                @on_response.delete(req_id)
                log_debug() {"after onResponse: callbacks = #{@on_response}"}
            end
        end
        if hash["NAME"] == PUSH_KEY
            on_push = @on_response[PUSH_KEY]
            if not on_push.nil?
                on_push.call(hash["event"], JSON.parse(hash["payload"]))
            end
        end
    end
end
