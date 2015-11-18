#-*- coding: utf-8 -*-
require_relative './processing'
require_relative '../compile/conditions'

#= フィルタリング処理クラス
#
#@author NICT
#
class Filter < Processing

    # フィルタリング処理を実施する。
    # フィルタリング条件を満たすデータのみを送信する。
    #
    #@param [Hash] processing_data 中間処理データ
    #@return フィルタリングを行なったデータ（入力データと同じフォーマット）
    #
    def execute(processing_data)
        return processing_values(processing_data, :select) { |data|
            Conditions.ok?(@conditions, data)
        }
    end
end

