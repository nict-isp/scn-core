# -*- coding: utf-8 -*-
require_relative './base_method'

module DSN

    #= Discoveryメソッドクラス
    # DSN記述のdiscoveryメソッドを解析する。
    #
    #@author NICT
    #
    class DiscoveryMethod
        # メソッド名
        METHOD_NAME = "discovery"

        # discovery構文を解析する。
        #
        #@param [DSNText] dsn_text DSN記述のメソッド構文部
        #@param [String] num 行数
        #@return [Hash<String, String|Array>] 検索属性
        #@raise [ArgumentError] メソッドとして,正しい形式でない場合
        #
        def self.parse(dsn_text)
            log_trace(dsn_text)

            format = nil  # formatチェックは個別実装
            attributes = BaseMethod.parse(dsn_text, METHOD_NAME, format)
            log_debug(){"#{attributes}"}

            attr_hash = {}
            attributes.each do |attr|
                name, value = DSNText.split(attr.single_line, "=", 2)

                # name, valueに正しく分離できない場合はエラー
                if name.nil? || value.nil?
                    raise DSNInternalFormatError, ErrorMessage::ERR_DISCOVERY_ATTR
                end
                log_debug(){"#{name}, #{value}"}

                # 複合条件の場合はvalueとして配列の文字列が返る。
                # 処理簡潔化のため、要素1個でも配列型を使う。
                if not attr_hash.key?(name)
                    attr_hash[name] = []
                end
                attr = attr_hash[name]

                if value[0] == "["
                    log_debug(){"#{value}"}
                    if value[-1] == "]"
                        multi_values = value[1..-2].split(",")
                        attr_hash[name].concat multi_values.map{|v| v.strip}
                    else
                        raise DSNFormatError.new(ErrorMessage::ERR_FORMAT_METHOD, dsn_text)
                    end
                else
                    log_debug(){"#{value}"}
                    attr << value
                end
            end

            attr_hash = self._multi_discovery(attr_hash)

            return attr_hash
        end

        # discovery構文か判定する
        #
        #@param [String] text メソッドの文字列
        #@return [Boolean] メソッドの一致
        #
        def self.is_method?(text)
            return text =~ /^#{METHOD_NAME}/
        end

        # 複数 discovery 用にキーを設定する。
        #
        #@param [Hash<String, String|Array>] 検索属性 
        #@return [Hash<String, String|Array>] 検索属性
        #@raise [DSNFormatError] multiキーの値が1以上の整数でない場合
        #
        def self._multi_discovery(attr_hash)
            if attr_hash.has_key?(KEY_MULTI)
                multi = attr_hash[KEY_MULTI][0].to_i
                if multi < 1
                    raise DSNFormatError.new(ErrorMessage::ERR_DISCOVERY_ATTR, multi)
                end
            else
                # 省略されている場合は、デフォルトで「1」を設定する。
                attr_hash[KEY_MULTI] = ["1"]
            end

            return attr_hash
        end
    end
end
