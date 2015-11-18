# -*- coding: utf-8 -*-
require_relative './base_method'
require_relative './conditions'

module DSN

    #= SelectMethodメソッドクラス
    # DSN記述のselectメソッドを解析する。
    #
    #@author NICT
    #
    class SelectMethod < BaseMethod
        # メソッド名
        METHOD_NAME = "select"

        # 空の場合の中間コード出力
        HASH_EMPTY = []

        #@return [Array] 空の場合の中間コード出力
        attr_reader :hash_empty

        #@param [Array<String>] name セレクト対象のデータ名
        #
        def initialize(names)
            @names      = names
            @hash_empty = HASH_EMPTY
        end

        #フィルタメソッドに対応した文字列か判定する。
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # selectメソッド構文を解析する。
        #
        #@param [DSNText] text メソッドの文字列
        #@return [Array<String>] メソッドの引数の配列
        #
        def self.parse(text)
            # フォーマットの定義
            format = nil
            args = BaseMethod.parse(text, METHOD_NAME, format)

            names = []
            args.each do |arg|
                names << arg.single_line
            end

            return SelectMethod.new(names)
        end

        #中間コードに変換する
        def to_hash()

            if @names.nil?()
                result = @hash_empty
            else
                result = []
                @names.each do |name|
                    result << {KEY_SELECT_NAME => name}
                end
            end
            return result
        end
    end
end
