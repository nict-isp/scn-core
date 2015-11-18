#-*- coding: utf-8 -*-
require_relative './processing'

#@pribate
#= 集約・統合処理定義クラス
#
module AggrefateDefine
    # 項目
    NAME  = "name"

    UNIT  = "unit"
    EAST  = "east"
    WEST  = "west"
    NORTH = "north"
    SOUTH = "south"
    START = "start"

    ENDE  = "end"
    MAX   = "max"
    MIN   = "min"
    AVG   = "avg"
    SUM   = "sum"
    COUNT = "count"
end

#= 集約・統合処理クラス
#
#@author NICT
#
class Aggregate < Processing
    include AggrefateDefine
    include TimeSpaceProcessing

    #@param [Hash] conditions 中間処理要求
    #
    def initialize(conditions)
        super
        @name = conditions["data_name"]
        @time = get_time_info(conditions["time"])
        @latitude, @longitude = get_space_info(conditions["space"])
        reset()
    end

    # 集約・統合処理を実施する
    # 時空間を指定間隔に分割した後、
    # 同じインデックスを持つデータを集計し、その結果を送信データとする。
    #
    #@param [Hash] processing_data 中間処理データ
    #@return 集約・統合処理を行なったデータ
    #@example 集約・統合データ
    #[
    #   {
    #       "name" => "rainfall",
    #       "west" => 130.0, "east" => 131.0,
    #       "south" => 35.0, "north" => 36.0,
    #
    #       "start" => "2015/01/01T00:00:00",
    #       "end"   => "2015/01/01T00:00:30",
    #
    #       "max"   => 30.0,
    #       "min"   => 5.0,
    #       "avg"   => 10.0,
    #       "sum"   => 1000.0,
    #       "count" => 100,
    #   }, {
    #       "name" => "rainfall",
    #       "west" => 131.0, "east" => 132.0,
    #       "south" => 35.0, "north" => 36.0,
    #
    #       "start" => "2015/01/01T00:00:00",
    #       "end"   => "2015/01/01T00:00:30",
    #
    #       :
    #   }
    #]
    #
    def execute(processing_data)
        processing_values(processing_data, :each) { |value|
            time_index = get_index(@time, value) { |time| time_to_sec(time) }
            lat_index  = get_index(@latitude, value)
            long_index = get_index(@longitude, value)
            next if time_index.nil? || lat_index.nil? || long_index.nil?  # 範囲外は集計しない

            @temp[time_index][lat_index][long_index] << value[@name]
        }
        return get_result()
    end

    private

    # 集計データをクリアする。
    #
    def reset()
        # 三重ハッシュのデフォルト値を配列に設定する。
        @temp = Hash.new{ |time_hash, time|
            time_hash[time] = Hash.new{ |lat_hash, lat|
                lat_hash[lat] = Hash.new{ |long_hash, long|
                    long_hash[long] = []
                }
            }
        }
    end

    #@private
    # 蓄積したデータを集計して返す。蓄積したデータはクリアする。
    #
    #@return [Hash] 集計後のデータ（データ形式はupdate_infoを参照）
    #
    def get_result()
        result = []
        @temp.each { |time, time_hash|
            info = {NAME => @name}
            info[START], info[ENDE] = get_start_end(@time, time) { |value| sec_to_time(value) }
            time_hash.each { |lat, lat_hash|
                info[SOUTH], info[NORTH] = get_start_end(@latitude, lat)
                lat_hash.each { |long, values|
                    info[WEST], info[EAST] = get_start_end(@longitude, long)

                    # インデックス毎に集計
                    summary = {}
                    summary[SUM] = values.inject(0) {|sum, value| sum += value }
                    summary[COUNT] = values.size
                    summary[AVG] = summary[SUM] / summary[COUNT]
                    summary[MIN], summary[MAX] = values.minmax

                    log_debug { "info = #{info}, summary = #{summary}"}
                    result << summary.merge(info)
                }
            }
        }
        reset()    # 出力済みのデータを削除
        return result
    end
end

