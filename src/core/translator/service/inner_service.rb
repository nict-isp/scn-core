# -*- coding: utf-8 -*-
require_relative './service'

#= インナーサービスクラス
# オーバーレイ内のみで動作するサービスクラス
#
#@author NICT
#
class InnerService < Service

    #@see Service#initialize
    def initialize(service_id, service_name, service_info, ip)
        super

        @running = false
        update(service_info)
    end

    # サービス入力（オーバーライドして使用）
    #
    #@param [Array<Hash>] data 受信データ
    #@param [Integer] size 受信データサイズ
    #@param [String] channel_id 送信元チャネルID
    #@return [void]
    #
    def receive_data(data, size, channel_id)
        log_trace(data, size, channel_id)
        
        # 入力をそのまま出力する例
        # ProcessingManager.send_data(@id, data, size)
    end

    # サービス出力（オーバーライドして使用）
    #
    #@return [void]
    #
    def send_data()
        log_trace()
        # nop
    end

    # サービス情報を更新
    #
    #@param [Hash] サービス情報
    #@return [void]
    #
    def update(service_info)
        log_debug{"service_info = #{service_info}"}
        @info = service_info
    end
 
    #@return [Integer] データ送信周期
    #
    def get_interval()
        return @info.fetch("interval", 30)
    end

    # サービス出力停止
    #
    #@return [void]
    #
    def stop()
        @running = false
    end

    # サービス出力開始
    #
    #@return [void]
    #
    def start()
        unless @running
            @running = true
            @latest  = Time.now

            Thread.new do
                while @running
                    begin
                        sleep 0.2
                        now = Time.now
                        if now - @latest >= get_interval()
                            log_trace()
                            @latest = now
                            send_data()
                        end
                    rescue
                        log_error("", $!)
                    end
                end
            end
        end
    end
end
