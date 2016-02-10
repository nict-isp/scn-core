# -*- coding: utf-8 -*-
require 'json'

#= サービスクラス
# SCNミドルウェア上で動作するサービスの定義クラス
#
#@author NICT
#
class Service

    #@return [String] サービスID
    attr_reader :id
    #@return [String] サービス名
    attr_reader :name
    #@return [Hash] サービス情報
    attr_accessor :info
    #@return [String] サービスIP
    attr_reader :ip
    #@return [Integer] データ受信用ポート番号
    attr_reader :port

    #@param [String] id サービスID
    #@param [String] name サービス名
    #@param [Hash] info サービス情報
    #@param [Integer] port データ受信用ポート番号
    #
    def initialize(id, name, info, ip, port = nil)
        @id       = id
        @name     = name
        @info     = info
        @ip       = ip
        @port     = port
    end

    #@see Object#marshal_dump
    def marshal_dump()
        # シリアライザブルな状態を保つため、伝播に必要な情報のみをダンプ
        return [@id, @name, @info, @ip, @port]
    end

    #@see Object#marshal_load
    def marshal_load(array)
        @id, @name, @info, @ip, @port = array
    end

    #@return [Hash] サービス情報
    #
    def to_info()
        return {
            "id"   => @id,
            "name" => @name,
            "info" => @info,
            "ip"   => @ip,
        }
    end

    #@return [Integer] 単位時間あたりの送信データサイズ(byte/s)
    #@example サービス情報設定例
    #     {
    #         "data_size" => 1024,
    #         "device_info" => {
    #             "capability" => {
    #                 "frequency" => {
    #                     "type"  => "sec",
    #                     "count" => 10
    #                 }
    #             }
    #         }
    #     }
    #
    #
    def get_bps()
        bps = nil

        size, frequency_type, frequency_count = get_frequency()

        if size.nil?() || frequency_type.nil?() || frequency_count.nil?()
            log_debug() {"data size or frequency type or frequency count is not setting."}

        else
            begin
                data_num_per_sec = nil
                case frequency_type
                when "msec"
                    data_num_per_sec = frequency_count * 1000
                when "sec"
                    data_num_per_sec = frequency_count
                when "minute"
                    data_num_per_sec = frequency_count / 60
                when "hour"
                    data_num_per_sec = frequency_count / 3600
                else
                    log_error("frequency type(=#{frequency_type}) is not support.")
                end

                if not data_num_per_sec.nil?()
                    bps = size * data_num_per_sec
                end
            rescue
                log_error("invalid data format. size = #{size}, frequency count = #{frequency_count}")
            end
        end

        return bps
    end

    private

    #@return [Array]
    # (Integer) データサイズ
    # (String)  周期の単位
    # (Integer) 上記周期における出力数
    #
    def get_frequency()
        size            = nil
        frequency_type  = nil
        frequency_count = nil

        if @info.nil?()
            log_debug() {"service info is not setting."}

        else
            size        = @info["data_size"]
            device_info = @info["device_info"]

            if size.nil?() || device_info.nil?()
                log_debug() {"data_size or device_info is not setting."}

            else
                capability = device_info["capability"]
                if  capability.nil?()
                    log_debug() {"capability is not setting."}

                else
                    frequency = capability["frequency"]
                    if frequency.nil?()
                        log_debug() {"frequency is not setting."}

                    else
                        frequency_type  = frequency["type"]
                        frequency_count = frequency["count"]
                    end
                end
            end
        end

        return size, frequency_type, frequency_count
    end
end

