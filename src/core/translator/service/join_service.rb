# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative './inner_service'
require_relative '../../dsn/processing/virtual'

#= 結合サービスクラス
#
#@author NICT
#
class JoinService < MergeService
    
    #@see MergeService#start
    def start()
        # 中間処理は伝播できないため、ここでインスタンス化
        if @virtual.nil?
            @virtual = Virtual.new(@info)
        end

        super
    end

    #@see MergeService#update
    def update(service_info)
        super

        unless @virtual.nil?
            @virtual.update(service_info)
        end
    end
    
    #@see InnerService#send_data
    def send_data()
        data = @merge.get_result()
        data = @virtual.execute(data)
        ProcessingManager.send_data(@id, data, calc_size(data))
    rescue
        log_error("", $!)
    end
end 

