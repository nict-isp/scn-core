#-*- coding: utf-8 -*-
require_relative '../../utils'
require_relative './aggregate_service'
require_relative './merge_service'
require_relative './join_service'
require_relative './sox_service'

#= インナーサービスのファクトリクラス
#
#@author NICT
#
class InnerServiceFactory

    # データ処理クラスのインスタンスを生成
    #
    #@param [Hash] Servvice 中間処理要求
    #@return [Processing] 中間処理クラス
    #
    def self.get_instance(inner_id, name, inner_info, node_ip)
        log_debug {"inner_id = #{inner_id}, name = #{name}, inner_info = #{inner_info}, node_ip = #{node_ip}" }

        inner_type = inner_info["type"]
        case inner_type
        when "aggregate"
            service = AggregateService.new(inner_id, name, inner_info, node_ip)
        when "merge"
            service = MergeService.new(inner_id, name, inner_info, node_ip)
        when "join"
            service = JoinService.new(inner_id, name, inner_info, node_ip)
        when "sox"
            service = SOXService.new(inner_id, name, inner_info, node_ip)
        else
            log_warn("undefined service. (type=#{inner_type})")
            service = InnerService.new(inner_id, name, inner_info, node_ip) # 何もしない
        end

        return service   # 中間処理要求は、1要素しか持たない。
    end
end

