# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative './inner_service'
require_relative '../../dsn/processing/merge'

#= マージサービスクラス
#
#@author NICT
#
class MergeService < InnerService
    
    #@see InnerService#start
    def start()
        # 中間処理は伝播できないため、ここでインスタンス化
        if @merge.nil?
            @merge = Merge.new(@info)
        end

        super
    end

    #@return [Integer] データ送信周期
    #
    def get_interval()
        return @info.fetch("delay", 30)
    end

    #@see InnerService#receive_data
    def receive_data(data, size, channel_id)
        @merge.execute(data)
    end
    
    #@see InnerService#send_data
    def send_data()
        data = @merge.get_result()
        ProcessingManager.send_data(@id, data, calc_size(data))
    rescue
        log_error("", $!)
    end
end 

