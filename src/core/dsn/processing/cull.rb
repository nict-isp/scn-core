#-*- coding: utf-8 -*-
require_relative './processing'

#= 間引き処理のベースクラス
#
#@author NICT
#
class Cull < Processing
    include TimeSpaceProcessing

    #@param [Hash] conditions 中間処理要求
    #
    def initialize(conditions)
        super
        @numerator   = conditions["numerator"]
        @denominator = conditions["denominator"]
    end

    private

    # 間引き対象かを判定する。
    # 分母による剰余算の結果が、分子以上の時、間引き対象とする。
    #
    #@param [Integer] index データのインデックス
    #@return [True] 間引き対象である
    #@return [False] 間引き対象でない
    #
    def cull?(index)
        return index.nil? || (index % @denominator) >= @numerator
    end
end

#= 時刻による間引き処理クラス
#
#@author NICT
#
class CullTime < Cull

    #@param [Hash] conditions 中間処理要求
    #
    def initialize(conditions)
        super
        @time = get_time_info(conditions["time"])
    end

    # 時間による間引き処理を実施する。
    # 時間軸を指定間隔に分割した後、
    # そのインデックスに対する剰余算で間引き対象を決定する。
    # 間引き対象ではないデータのみを送信する。
    #
    #@example 時間による間引き例
    # denominator = 3, numerator = 2
    #
    # index
    # 0123456789..
    # ++-++-++-+..
    #
    # +: 送信対象
    # -: 間引き対象
    #@param [Hash] processing_data 中間処理データ
    #@return 時間による間引きを行なったデータ（入力データと同じフォーマット）
    #
    def execute(processing_data)
        return processing_values(processing_data, :select) { |value|
            time_index = get_index(@time, value) { |time| time_to_sec(time) }
            not(cull?(time_index))
        }
    end
end

#= 空間による間引き処理クラス
#
#@author NICT
#
class CullSpace < Cull

    #@param [Hash] conditions 中間処理要求
    #
    def initialize(conditions)
        super
        @latitude, @longitude = get_space_info(conditions["space"])
    end

    # 空間による間引き処理を実施する。
    # 緯度、経度の軸を指定間隔に分割した後、
    # そのインデックスに対する剰余算で間引き対象を決定する。
    # 間引き対象ではないデータのみを送信する。
    #
    #@example 空間による間引き例
    # denominator = 3, numerator = 2
    #
    # index
    # \0123456789..
    # 0++-++-++-+
    # 1++-++-++-+
    # 2----------..
    # 3++-++-++-+
    # 4++-++-++-+
    # :     :
    #
    # +: 送信対象
    # -: 間引き対象
    #@param [Hash] processing_data 中間処理データ
    #@return 時間による間引きを行なったデータ（入力データと同じフォーマット）
    #
    def execute(processing_data)
        return processing_values(processing_data, :select) { |value|
            lat_index  = get_index(@latitude, value)
            long_index = get_index(@longitude, value)
            (not(cull?(lat_index))) && (not(cull?(long_index)))
        }
    end
end

