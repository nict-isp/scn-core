#-*- coding: utf-8 -*-
require_relative '../../utils'
require_relative '../../utility/m2m_format'
require_relative '../compile/conditions'

#= 中間処理のベースクラス
#
#@author NICT
#
class Processing
    include DSN

    #@param [Hash] conditions 中間処理要求
    #
    def initialize(conditions)
        @conditions = conditions
    end

    # 中間処理を実行する
    #
    #@param [Hash] processing_data 中間処理対象のデータ
    #@return 中間処理実行後のデータ（入力データと同じフォーマット）
    #
    def execute(processing_data)
        return processing_data
    end

    private

    # 中間処理対象の値をEnumrableのメソッドにより取り出し、ブロック文による処理を実行する。
    #
    #@param [Hash] processing_data 中間処理データ
    #@param [Symbol] method_name Enumrableのメソッド名
    #@yieldparam [Hash] value 取り出したデータ要素
    #@yieldreturn [Object] Enumrableメソッドの戻り値
    #@return [Hash] Enumrableメソッドによる処理後の中間処理データ
    #
    def processing_values(processing_data, method_name, &block)
        if M2MFormat.formatted?(processing_data)
            result = processing_m2m_values(processing_data, method_name, &block)
        else
            result = processing_normal_values(processing_data, method_name, &block)
        end
        return result
    end

    # m2mデータに該当しないデータの値をEnumrableのメソッドにより取り出し、ブロック文による処理を実行する。
    #
    #@param [Hash] processing_data 中間処理データ
    #@param [Symbol] method_name Enumrableのメソッド名
    #@yieldparam [Hash] value 取り出したデータ要素
    #@yieldreturn [Object] Enumrableメソッドの戻り値
    #@return [Hash] Enumrableメソッドによる処理後の中間処理データ
    #
    def processing_normal_values(processing_data, method_name)
        data = processing_data.method(method_name).call { |value|
            yield(value)
        }
        return data
    end

    # M2Mデータver1.02の値をEnumrableのメソッドにより取り出し、ブロック文による処理を実行する。
    #
    #@param [Hash] processing_data 中間処理データ
    #@param [Symbol] method_name Enumrableのメソッド名
    #@yieldparam [Hash] value 取り出したデータ要素
    #@yieldreturn [Object] Enumrableメソッドの戻り値
    #@return [Hash] Enumrableメソッドによる処理後の中間処理データ
    #
    def processing_m2m_values(processing_data, method_name)
        data = M2MFormat.clone_data(processing_data)
        values = M2MFormat.get_values(data).method(method_name).call { |value|
            # EventWarehouse対応。必須データを格納する
            value["latitude"]  ||= nil
            value["longitude"] ||= nil
            value["altitude"]  ||= nil
            value["time"]      ||= nil
            yield(value)
        }
        M2MFormat.set_values(data, values)
        return data
    end

    # 中間処理で扱う共通のフォーマット
    #
    #@param [Numeric] start 開始値
    #@param [Numeric] ende 終了値
    #@param [Numeric] interval データ間隔
    #@param [String] label データ名
    #@return [Hash] 整形済みの情報
    #
    def to_info(start, ende, interval, label)
        return {
            "start"    => start,
            "end"      => ende,
            "interval" => interval,
            "label"    => label
        }
    end
end

#@private
#= 時空間処理モジュール
#
#@author NICT
#
module TimeSpaceProcessing

    private

    # 集計先のインデックスを算出する
    #
    #@param [Hash] info 集計用の定義情報（データ名、開始値、終了値、インターバル）
    #@param [Hash] data センサーデータ
    #@return [Integer] 集計先のインデックス
    #@return [Nil] 集計範囲を超える場合
    #
    def get_index(info, data)
        value = data[info["label"]]
        start = info["start"]
        ende  = info["end"]
        value = yield(value) if block_given?    # 計算可能な数値に変換
        return (start <= value && value < ende) ? ((value - start) / info["interval"]).to_i : nil
    end

    # 集計先のインデックスより、該当する集計範囲を算出する
    #
    #@param [Integer] 集計先のインデックス
    #@retrun [Object, Object] 開始値、終了値
    #
    def get_start_end(info, value)
        interval = info["interval"]
        start = value * interval + info["start"]
        ende  = [start + interval, info["end"]].min # 集計範囲を超えないように
        start = yield(start) if block_given?    # 元データのフォーマットに変換
        ende  = yield(ende)  if block_given?    # 元データのフォーマットに変換
        return start, ende
    end

    # 時刻情報を中間処理で扱う形にして取得する。
    #
    #@param [Hash] time 時刻情報のハッシュ
    #@return [Hash] 整形済みの時刻情報
    #
    def get_time_info(time)
        if time.kind_of?(Hash)
            time_unit_str = time["time_unit"]
            case time_unit_str
            when "second"
                time_unit = 1
            when "minute"
                time_unit = 60
            when "hour"
                time_unit = 60 * 60
            else
                log_warn("undefined time unit. (time_unit=#{time_unit_str})")
                time_unit = 1
            end
            time_info = to_info(
            time_to_sec(time["start_time"]),
            time_to_sec(time["end_time"]),
            time["time_interval"] * time_unit,
            time["data_name"]
            )
            time_info["unit"] = time_unit
        else
            time_info = nil
        end
        return time_info
    rescue
        log_error("invalid processing request. (time info#{time})", $!)
        return nil
    end

    # 空間情報を中間処理で扱う形にして取得する。
    #
    #@param [Hash] time 空間情報のハッシュ
    #@return [Hash, Hash] 整形済みの緯度、経度情報
    #
    def get_space_info(space)
        if space.kind_of?(Hash)
            latitude_info  = to_info(space["south"], space["north"], space["lat_interval"],  space["lat_data_name"])
            longitude_info = to_info(space["west"],  space["east"],  space["long_interval"], space["long_data_name"])
        else
            latitude_info  = nil
            longitude_info = nil
        end
        return latitude_info, longitude_info
    rescue
        log_error("invalid processing request. (space info#{space})", $!)
        return nil, nil
    end
end

