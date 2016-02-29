# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#

#= サービス検索クラス
# サービス検索のインターフェース
#
class ServiceDiscovery

    def search(query, service_list)
        raise NotImplementedError
    end
end

#= サービス検索クラス
# ハッシュ型のサービス検索に対応する。
#
class SimpleServiceDiscovery < ServiceDiscovery

    # query で指定された条件にマッチするサービスオブジェクトのリストを返す。
    #@example queryの例
    #   {
    #       "name" => "TestSend"
    #   }
    #
    #@param [Hash] query サービスの検索条件(nilの場合全検索)
    #@param [Hash{String=>Service}] service_list サービスオブジェクトのリスト
    #@return [Array] 検索にヒットしたサービスの配列
    #@raise [NoMethodError] 未サポートの検索クエリが指定された。
    #
    def search(query, service_list)
        log_trace(query, service_list)

        all_service_list = service_list.values

        if query.nil?() || query.empty?()
            # 全検索
            result = all_service_list

        else
            if query.is_a?(Hash)
                id   = query["id"]
                name = query["name"]

                if not id.nil?()
                    # サービスID検索
                    result = all_service_list.select { |service| id == service.id }
                elsif not name.nil?()
                    # サービス名検索
                    result = all_service_list.select { |service| name == service.name }
                else
                    # key/value検索
                    result = key_value_search(query, all_service_list)
                end
            else
                # エラーメッセージの出力有無は、呼び出し元で判断する。
                raise NoMethodError, "query(=#{query}) is not support."
            end
        end

        return result
    end

    private

    # key/valueのペアが一致するサービスのみ返す。
    #
    #@param [Hash] hash key/value
    #@param [Array] service_list 検索対象の配列
    #@return [Array] 検索にヒットしたサービスの配列
    #
    def key_value_search(hash, service_list)

        result = []

        service_list.each do |service|
            info = service.info
            next if info.nil?()

            match = true
            hash.each do |key, value|
                values = to_array(value)
                and_values = to_array(info[key]) & values
                if values.size > and_values.size
                    match = false
                    break
                end
            end
            # 検索結果リストへ追加する。
            result << service if match
        end

        return result
    end

    # 属性値を配列に変換する
    #
    #@param [String] value 属性値
    #@param [Hash] value 属性値
    #@param [Array] value 属性値
    #@return [Array] 属性値の配列
    #
    def to_array(value)
        case value
        when String
            values = [value]
        when Array
            values = value
        when Hash
            values = value.keys
        else
            values = []
        end
        return values
    end
end
