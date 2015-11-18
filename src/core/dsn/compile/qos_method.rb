# -*- coding: utf-8 -*-
require_relative './base_method'

module DSN

    #= QoSMethodメソッドクラス
    # DSN記述のQoSメソッドを解析する。
    #
    #@author NICT
    #
    class QoSMethod < BaseMethod
        # メソッド名
        METHOD_NAME = "qos"

        # 空の場合の中間コード出力
        HASH_EMPTY = {}

        #@return [Array] 空の場合の中間コード出力
        attr_reader :hash_empty

        # デフォルト優先度
        # priority が指定できるとユーザが好き勝手に数値を設定すると考えられ、
        # また、完全には優先度を保障できないため、DSN記述上では設定できないように
        # しておく。
        PRIORITY_DEFAULT = 100

        #@param [Integer] bandwidth バンド幅
        #@param [Integer] priority 通信優先度
        #
        def initialize(bandwidth, priority)
            @bandwidth  = bandwidth
            @priority   = priority
            @hash_empty = HASH_EMPTY
        end

        #qosメソッドに対応した文字列か判定する。
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # qosメソッド構文を解析する。
        #
        #@param [DSNText] text メソッドの文字列
        #@return [Array<String>] メソッドの引数の配列
        #
        def self.parse(text)
            # フォーマットの定義
            format = [[TYPE_INTEGER]]
            args   = BaseMethod.parse(text, METHOD_NAME, format)

            bandwidth = args[0].single_line
            priority  = PRIORITY_DEFAULT

            return QoSMethod.new(bandwidth, priority)
        end

        #中間コードに変換する
        def to_hash()

            if @bandwidth.nil?() && @priority.nil?()
                result = @hash_empty
            else
                result = {
                    KEY_QOS_BANDWIDTH => @bandwidth,
                    KEY_QOS_PRIORITY  => @priority
                }
            end
            return result
        end
    end
end
