# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require 'date'

require_relative '../utils'

#= M2Mデータフォーマットクラス
#
#@author NICT
#
class M2MFormat

    # m2mデータフォーマットより、時刻データを文字列で取得する
    #
    #@param [Hash] data m2mデータ
    #@return [String] 時刻データ
    #
    def self.get_time_str(data)
        return data["Data"]["data"]["values"][0]["time"][0..22] #タイムゾーン非対応
    end

    # m2mデータフォーマットより、時刻データを取得する
    #
    #@param [Hash] data m2mデータ
    #@return [DateTime] 時刻データ
    #
    def self.get_time(data)
        time_str = get_time_str(data)
        return DateTime.strptime(time_str, "%Y-%m-%dT%H:%M:%S") #ミリ秒非対応
    end

    # m2mデータフォーマットより、緯度データを取得する
    #
    #@param [Hash] data m2mデータ
    #@return [Float] 緯度データ
    #
    def self.get_latitude(data)
        return data["MetaData"]["sensor_info"]["device_info"]["latitude"]
    end

    # m2mデータフォーマットより、経度データを取得する
    #
    #@param [Hash] data m2mデータ
    #@return [Float] 経度データ
    #
    def self.get_longitude(data)
        return data["MetaData"]["sensor_info"]["device_info"]["longitude"]
    end

    # m2mデータフォーマットより、降雨データを取得する
    #
    #@param [Hash] data m2mデータ
    #@return [Float] 降雨データ
    #
    def self.get_rainfall(data)
        return data["Data"]["data"]["values"][0]["average_rainfall"]
    end

    # m2mデータフォーマットかどうかを判別する
    #
    #@param [Hash] data m2mデータ
    #@return {Boolean] m2mデータの時、true
    #
    def self.formatted?(data)
        return (not(get_m2m_version(data).nil?))
    end

    # 現行バージョンのデータに変換する
    #
    #@param [Hash] data m2mデータ
    #@return [Hash] 現行バージョンのm2mデータ
    #
    def self.convert_current_format(data)
        case get_m2m_version(data)
        when 1.01
            result = convert_101_to_102(data)
        else
            result = clone_data(data)    # 使用時に元データが壊れないよう、cloneしておく
        end
        return result
    end

    #@param [Hash] data m2mデータ
    #@return [Float] m2mデータフォーマットのバージョン
    #
    def self.get_format_version(data)
        return data["MetaData"]["primary"]["format_version"]
    end

    #@param [Hash] data m2mデータ
    #@param [Float] version m2mデータフォーマットのバージョン
    #
    def self.set_format_version(data, version)
        data["MetaData"]["primary"]["format_version"] = version
    end

    #@param [Hash] data m2mデータ
    #@return [Hash] センサーのデバイス情報
    #
    def self.get_device_info(data)
        return data["MetaData"]["sensor_info"]["device_info"]
    end

    #@param [Hash] data m2mデータ
    #@return [Array] センサーのスキーマ情報
    #
    def self.get_schema(data)
        return data["MetaData"]["sensor_info"]["schema"]
    end

    #@param [Hash] data m2mデータ
    #@return [Array] データ部のデータ本体
    #
    def self.get_values(data)
        return data["Data"]["data"]["values"]
    end

    #@param [Hash] data m2mデータ
    #@param [Array] values データ部のデータ本体
    #
    def self.set_values(data, values)
        data["Data"]["data"]["values"] = values
    end

    # ver1.01のデータをver1.02のフォーマットに変換する。
    # ※メタデータ部は、緯度経度を除いて全て同じとする
    #
    #@param [Hash] old_data 単数のver1.01のm2mデータ
    #@param [Array] old_data 複数のver1.01のm2mデータ
    #@retrun [Hash] ver1.02のm2mデータ
    #@retrun [Nil] データが存在しないとき
    #
    def self.convert_101_to_102(old_data)
        data_list = to_m2m_array(old_data)
        return nil if data_list.nil?

        new_data = clone_data(data_list[0])

        # データスキーマに緯度経度高度を追加
        schema = get_schema(new_data)
        schema << { "type" => "numeric", "unit" => "degree", "name" => "latitude" }
        schema << { "type" => "numeric", "unit" => "degree", "name" => "longitude" }
        schema << { "type" => "numeric", "unit" => "m", "name" => "altitude" }

        # データ部に緯度経度を追加、valuesに全ての値を詰める（メタデータを1つに集約）
        values    = []
        data_list.each do |data|
            get_values(data).each do |value|
                value["latitude"]  = get_latitude(data)
                value["longitude"] = get_longitude(data)
                value["altitude"]  ||= nil
                values << value
            end
        end

        set_format_version(new_data, 1.02)
        set_values(new_data, values)

        return new_data
    end

    # m2mデータのバージョン情報を取得する
    #
    #@param [Hash] m2mデータ
    #@return [Float] バージョン情報
    #@return [Nil] m2mデータではない時
    #
    def self.get_m2m_version(data)
        return get_format_version(to_m2m_array(data)[0])
    rescue
        return nil
    end

    # スキーマ情報から必要な情報のみ抽出する。
    #
    #@param [Hash] m2mデータ
    #@param [Array] 抽出するスキーマ
    #@return [void]
    #
    def self.extract_schema(data, colmuns)
        schemas = get_schema(data)
        schemas.select! { |schema|
            colmuns.any? { |colmun| schema["name"] == colmun }
        }
    end

    private

    # 単数または複数のm2mデータを配列型に変換（統一）する。
    #
    #@param [Hash] data 単数のm2mデータ
    #@param [Array] data 複数のm2mデータ
    #@return [Array<Hash>] 配列型のm2mデータ
    #
    def self.to_m2m_array(data)
        case
        when data.kind_of?(Array) && data.size > 0
            data_list = data
        when data.kind_of?(Hash)
            data_list = [data]
        else
            data_list = nil
        end
        return data_list
    end

    # 使用時にデータが壊れないよう、データを複製する
    # パフォーマンスを考慮して、values はdeep copyしない
    #@param [Hash] original 元データ
    #@retrun [Hash] 複製データ
    #
    def self.clone_data(original)
        data = original["Data"]
        return {
            "MetaData" => deep_copy(original["MetaData"]),
            "Data" => {
            "data" => {
            "values" => data["data"]["values"].dup,
            "data_id" => data["data"]["data_id"]
            }
            }
        }
    end

end
