# -*- coding: utf-8 -*-
require "rjb"
require "digest/md5"
require "json"

# Java VMを起動する。
Rjb::load

module SoxLib
    extend Rjb
    SoxConnection = import("jp.ac.keio.sfc.ht.sox.soxlib.SoxConnection")
    SoxDevice     = import("jp.ac.keio.sfc.ht.sox.soxlib.SoxDevice")
end

#= SOXコネクタクラス
# SOXサーバと接続しデータを取得するクラス
#
# 必要な jar ファイルを、下記のパスに配置しておく必要がある。
# $JAVA_HOME/jre/lib/ext
#
#   jxmpp-core-0.4.1.jar
#   jxmpp-util-cache-0.5.0-alpha2.jar
#   simple-xml-2.7.1.jar
#   smack-core-4.1.5.jar
#   smack-extensions-4.1.5.jar
#   smack-java7-4.1.5.jar
#   smack-tcp-4.1.5.jar
#   xpp3-1.1.6.jar
#
#@author NICT
#
class SOXConnector

    #@param [String] url SOXサーバのURL
    #
    def initialize(url)
        @con = SoxLib::SoxConnection.new(url, false)
        @url = url
    end

    # SOXサーバから指定したデータを取得する。
    #
    #@param [String] name SOXサーバから取得するデータ名
    #@return [Hash] M2Mデータフォーマット形式のSOXデータ
    #
    def get_data(name)
        device      = SoxLib::SoxDevice.new(@con, name);
        device_info = device.getDevice()
        transducers = device_info.getTransducers()
        values      = device.getLastPublishData().getTransducerValue()

        return _to_m2m_format(device_info, transducers, values)

    rescue Exception
        return Hash.new()
    end

    private

    # SOXサーバから取得したデータをM2Mデータフォーマットに変換する。
    #
    def _to_m2m_format(device_info, transducers, values)

        title    = device_info.getName()
        time_now = Time.now
        data_id  = title + time_now.instance_eval{"%s%06d" % [strftime("%Y%m%d%H%M%S"), time_now.usec]}

        values, schema = _to_values_schema_array(transducers, values)

        data                                                                   = Hash.new()
        data["data"]                                                           = Hash.new()
        data["data"]["values"]                                                 = values
        data["data"]["data_id"]                                                = data_id

        data_str = JSON.dump(data)

        meta                                                                   = Hash.new()
        meta["primary"]                                                        = Hash.new()
        meta["primary"]["format_version"]                                      = 1.02
        meta["primary"]["title"]                                               = title
        meta["primary"]["provenance"]                                          = Hash.new()
        meta["primary"]["provenance"]["source"]                                = Hash.new()
        meta["primary"]["provenance"]["source"]["info"]                        = @url
        meta["primary"]["provenance"]["source"]["contact"]                     = "" #
        meta["primary"]["provenance"]["create_by"]                             = Hash.new()
        meta["primary"]["provenance"]["create_by"]["contact"]                  = "" #
        meta["primary"]["provenance"]["create_by"]["time"]                     = time_now.instance_eval{"%s.%06d" % [strftime("%Y-%m-%d %H:%M:%S"), time_now.usec]}
        meta["primary"]["tag"]                                                 = ""
        meta["primary"]["timezone"]                                            = "+0900"
        meta["primary"]["security"]                                            = "public"
        meta["primary"]["id"]                                                  = "http://m2m.nict.go.jp/m2m_data/?id=" + data_id
        meta["sensor_info"]                                                    = Hash.new()
        meta["sensor_info"]["data_hash"]                                       = Digest::MD5.hexdigest(data_str)
        meta["sensor_info"]["data_link"]                                       = Hash.new()
        meta["sensor_info"]["data_link"]["uri"]                                = "next_data"
        meta["sensor_info"]["data_link"]["data_id"]                            = data_id
        meta["sensor_info"]["data_format"]                                     = "json"
        meta["sensor_info"]["device_info"]                                     = Hash.new()
        meta["sensor_info"]["device_info"]["name"]                             = nil
        meta["sensor_info"]["device_info"]["serial_no"]                        = nil
        meta["sensor_info"]["device_info"]["capability"]                       = Hash.new()
        meta["sensor_info"]["device_info"]["capability"]["frequency"]          = Hash.new()
        meta["sensor_info"]["device_info"]["capability"]["frequency"]["count"] = 10
        meta["sensor_info"]["device_info"]["capability"]["frequency"]["type"]  = "minute"
        meta["sensor_info"]["device_info"]["ownership"]                        = "NICT"
        meta["sensor_info"]["device_info"]["ipaddress"]                        = nil
        meta["sensor_info"]["device_info"]["id"]                               = nil
        meta["sensor_info"]["data_profile"]                                    = device_info.getDeviceType().toString()
        meta["sensor_info"]["data_size"]                                       = data_str.length()
        meta["sensor_info"]["schema"]                                          = schema

        return {"MetaData" => meta, "Data" => data}
    end

    # M2MデータフォーマットのMetaData部のshcema、Data部のvalueの配列を生成する。
    #
    def _to_values_schema_array(transducers, values)
        values_list = []
        schema_list = []
        values_hash = Hash.new()

        for i in 0..(values.size()-1)
            value = values.get(i)

            case value.getId()
            when "latitude"
                # time
                values_hash["time"]      = value.getTimestamp()
                schema_list << {"type" => "string",  "name" => "time"}

                # latitude
                values_hash["latitude"]  = value.getRawValue().to_f()
                schema_list << {"type" => "numeric", "name" => "latitude",  "unit" => "degree"}

            when "longitude"
                # longitude
                values_hash["longitude"] = value.getRawValue().to_f()
                schema_list << {"type" => "numeric", "name" => "longitude", "unit" => "degree"}

                # altitude
                values_hash["altitude"]  = 0.0
                schema_list << {"type" => "numeric", "name" => "altitude",  "unit" => "m"}

            else
                unit = ""
                for i in 0..(transducers.size()-1)
                    t = transducers.get(i)

                    if t.getName().to_s() == value.getId()
                        unit = t.getUnits().to_s()
                        break
                    end
                end

                if unit == ""
                    # string
                    values_hash[value.getId()] = value.getRawValue()
                    schema_list << {"type" => "string", "name" => value.getId()}

                else
                    # numeric
                    values_hash[value.getId()] = value.getRawValue().to_f()
                    schema_list << {"type" => "numeric", "name" => value.getId(), "unit" => unit}
                end
            end
        end

        values_list << values_hash

        return values_list, schema_list
    end
end

