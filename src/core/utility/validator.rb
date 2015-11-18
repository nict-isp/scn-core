# -*- coding: utf-8 -*-
require_relative '../utils'

#= バリデーションクラス
# 
#@author NICT
#
class Validator

    # サービス情報のフォーマット
    SERVICE_INFO_FORMAT = /^[a-zA-Z0-9][a-zA-Z0-9_-]*$/

    # サービス情報のフォーマットをチェックする。
    #
    #@param info [Hash<String, String>] サービス情報
    #@return [void]
    #@raise [ArgumentError] サービス情報が無効な時
    #
    def self.service_info(info)
        if info.nil?()
            return
        end

        if info.kind_of?(Hash)
            info.each { |key, value|
                self.service_info_key(key)
                self.service_info_value(value)
            }
        else
            raise ArgumentError, "info must be Hash. (info=#{info})"
        end
    end

    # サービス情報のキーのフォーマットをチェックする。
    #
    #@param key [String] サービス情報のキー
    #@return [void]
    #@raise [ArgumentError] サービス情報のキーが無効な時
    #
    def self.service_info_key(key)
        if not key.kind_of?(String)
            raise ArgumentError, "key must be String of info. (key=#{key})"
        end

        if not key =~ SERVICE_INFO_FORMAT
            raise ArgumentError, "invalid key of info. (key=#{key})"
        end
    end

    # サービス情報の値のフォーマットをチェックする。
    #
    #@param value [String] サービス情報の値
    #@param value [Hash]   サービス情報の値（Hash型、一階層まで）
    #@param value [Array]  サービス情報の値（Array型、一階層まで）
    #@return [void]
    #@raise [ArgumentError] サービス情報の値が無効な時
    #
    def self.service_info_value(value)
        case value
        when String
            values = []
        when Array
            values = value
        when Hash
            values = value.keys
        else
            raise ArgumentError, "value must be String or Array or Hash of info. (value=#{value})"
        end

        values.each { |v|
            if not v.kind_of?(String)
                raise ArgumentError, "value must be String of info. (value=#{v})"
            end
        }
    end
end

