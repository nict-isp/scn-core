#-*- coding: utf-8 -*-
require_relative '../../utils'
require_relative './processing'
require_relative './filter'
require_relative './cull'
require_relative './string'
require_relative './virtual'

#= 中間処理のファクトリクラス
#
#@author NICT
#
class ProcessingFactory

    # データ処理クラスのインスタンスを生成
    #
    #@param [Hash] processing 中間処理要求
    #@return [Processing] 中間処理クラス
    #
    def self.get_instance(processing)
        processing.each do |name, param|
            log_debug {"name = #{name}, param = #{param}" }

            case name
            when "filter"
                proccesing = Filter.new(param)
            when "cull_time"
                proccesing = CullTime.new(param)
            when "cull_space"
                proccesing = CullSpace.new(param)
            when "string"
                proccesing = StringOperation.new(param)
            when "virtual"
                proccesing = Virtual.new(param)

            # 以下はインナーサービスで直接生成する
            #when "aggregate"
            #when "merge"
            else
                log_warn("undefined processing. (name=#{name})")
                proccesing = Processing.new({}) # 何もしない
            end

            return proccesing   # 中間処理要求は、1要素しか持たない。
        end
    end
end
