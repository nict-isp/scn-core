#-*- coding: utf-8 -*-
require_relative './processing'

#@private
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

#= 集約・統合処理クラス（インナーサービス向け）
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

        reset()
        update(conditions)
    end

    # 中間処理要求を更新する。 
    # 
    #@param [Hash] conditions 中間処理要求
    #@return [void]
    #
    def update(conditions)
        @conditions = conditions

        @name  = conditions["data_name"]
        @delay = conditions["delay"]
        space = conditions["space"]
        if space.nil?
            @latitude, @longitude = [nil, nil]
        else
            @latitude, @longitude = get_space_info(space)
        end
    end

    # 集約・統合処理を実施する
    # 空間を指定間隔に分割した後、同じインデックスを持つデータを集計する。
    #
    #@param [Hash] processing_data 中間処理データ
    #@retrun [Array] 空データ（いったん集約するため）
    #
    def execute(processing_data)
        processing_values(processing_data, :each) { |value|
            if @time < time_to_sec(value["time"]) + @delay && value.has_key?(@name)
                key = get_key(value)
                @cache[key] << value
            end
        }   
        return []
    end

    # 蓄積したデータを集計して返す。蓄積したデータはクリアする。
    #
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
    def get_result()
        log_trace()
        result = []

        now  = Time.now.to_i
        info = {
            START => sec_to_time(@time),
            ENDE  => sec_to_time(now),
        }
        @cache.each do |(lat, long), values|
            if @latitude.nil?
                # 空間の指定がない場合は、全データを包括する空間を範囲とする
                info[SOUTH], info[NORTH] = values.each_with_object([]) {|v, a| a << v["latitude"]}.minmax
                info[WEST],  info[EAST]  = values.each_with_object([]) {|v, a| a << v["longitude"]}.minmax
            else
                info[SOUTH], info[NORTH] = get_start_end(@latitude, lat)
                info[WEST],  info[EAST]  = get_start_end(@longitude, long)
            end

            # インデックス毎に集計
            summary = {}
            summary[SUM]   = values.inject(0) {|sum, value| sum += value[@name] }
            summary[COUNT] = values.size
            summary[AVG]   = summary[SUM] / summary[COUNT]
            summary[MIN], summary[MAX] = values.each_with_object([]) {|v, a| a << v[@name]}.minmax
            result << summary.merge(info)
        end
        log_trace(result)
        reset(now)  # 出力済みのデータを削除
        return result
    end

    private

    # 集計データのキーを作成する。
    # 
    def get_key(value)
        if @latitude.nil?
            # 空間の指定がない場合は、すべて同じキーで集計する
            return [nil, nil]
        else
            return [get_index(@latitude, value), get_index(@longitude, value)]
        end
    end

    # 集計データをクリアする。
    #
    def reset(now = nil)
        if now.nil?
            now = Time.now.to_i
        end
        @time  = now 
        @cache = SyncHash.new{|h, k| h[k] = []}
    end
end

