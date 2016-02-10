#-*- coding: utf-8 -*-
require_relative './processing'


#= マージ処理クラス（インナーサービス向け）
#
#@author NICT
#
class Merge < Processing
    
    #@param [Hash] conditions 中間処理要求
    #
    def initialize(conditions = {})
        super

        reset()
        reset() # 2回呼出でold_cahceまで生成
    end

    # 中間処理要求を更新する。 
    # 
    #@param [Hash] conditions 中間処理要求
    #@return [void]
    #
    def update(conditions)
        @conditions = conditions
    end

    # マージ処理を実施する
    # 時空間をキーとして、複数のデータソースからのデータをマージする。
    # キーによるマージのため、データを必ず1動作周期以上保持する。
    #
    #@param [Hash] processing_data 中間処理データ
    #@retrun [Array] 空データ（いったん保持するため）
    #
    def execute(processing_data)
        processing_values(processing_data, :each) { |value|
            key = get_key(value)

            # 保持中のデータにマッチするかを確認
            if @old_cache.has_key?(key)
                @old_cache[key].merge!(value)
            else
                @new_cache[key].merge!(value)
            end
        }   
        return []
    end

    # 時空間で整列したマージ結果を取得する。
    #
    #@return [Array<Hash>] 時空間で整列したデータ
    #
    def get_result()
        log_trace()
        result = @old_cache.values.sort_by{|value| get_key(value)}
        reset()
        return result
    end

    private

    # ハッシュ、ソートに用いる時空間のキーを生成する
    #
    def get_key(value)
        return [[value["time"]], [value["latitude"]], [value["longitude"]]]
    end

    def reset()
        @old_cache = @new_cache
        @new_cache = SyncHash.new{|h, k| h[k] = {}}
    end
end

