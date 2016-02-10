# -*- coding: utf-8 -*-
require_relative './inner_service'
require_relative '../../utility/sox_connector'

#= SOXセンサーサービス
#
#@author NICT
#
class SOXService < InnerService

    SOX_HOST         = "sox.ht.sfc.keio.ac.jp"
    COLLECT_INTERVAL = 30

    #@see InnerService#start
    def start()
        @sox      = SOXConnector.new(SOX_HOST)

        super

    rescue Exception
        log_error("invalid SOX host. (#{SOX_HOST})", $!)
    end

    #@see InnerService#update
    def update(service_info)
        super
    end

    #@return [Integer] データ送信周期
    #
    def get_interval()
        return COLLECT_INTERVAL
    end

    #@see InnerService#receive_data
    def receive_data(data, size, channel_id)
        super
    end

    #@see InnerService#send_data
    def send_data()
        source = @info["query"]["modifier"]

        if source.nil?()
            log_warn("SOX source is not defined.")
        else
            data = @sox.get_data(source[0])
            Supervisor.send_data(@id, data, calc_size(data), nil, true)
        end
    rescue
        log_error("", $!)
    end
end

