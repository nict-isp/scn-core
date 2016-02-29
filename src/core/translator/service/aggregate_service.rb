# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative './inner_service'
require_relative '../../dsn/processing/aggregate'

#= 集約・統合サービスクラス
#
#@author NICT
#
class AggregateService < InnerService
    
    #@see InnerService#start
    def start()
        # 中間処理は伝播できないため、ここでインスタンス化
        if @aggregate.nil?
            @aggregate = Aggregate.new(@info)
        end

        super
    end

    #@see InnerService#update
    def update(service_info)
        super

        unless @aggregate.nil?
            @aggregate.update(service_info)
        end
    end

    #@return [Integer] データ送信周期
    #
    def get_interval()
        return @info.fetch("timeout", 30)
    end

    #@see InnerService#receive_data
    def receive_data(data, size, channel_id)
        @aggregate.execute(data)
    end
    
    #@see InnerService#send_data
    def send_data()
        data = @aggregate.get_result()
        ProcessingManager.send_data(@id, data, calc_size(data))
    end
end 

