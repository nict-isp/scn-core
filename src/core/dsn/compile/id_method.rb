# -*- coding: utf-8 -*-
require_relative './base_method'

module DSN

    #= IDMethodメソッドクラス
    # DSN記述のidメソッドを解析する。
    #
    #@author NICT
    #
    class IDMethod < BaseMethod
        # メソッド名
        METHOD_NAME = "id"

        # 空の場合の中間コード出力
        HASH_EMPTY = ""

        #@return [Array] 空の場合の中間コード出力
        attr_reader :hash_empty

        #@param [String] id チャネルの識別子
        #
        def initialize(id)
            @id         = id
            @hash_empty = HASH_EMPTY
        end

        #idメソッドに対応した文字列か判定する。
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # idメソッド構文を解析する。
        #
        #@param [DSNText] text メソッドの文字列
        #@return [Array<String>] メソッドの引数の配列
        #
        def self.parse(text)
            # フォーマットの定義
            format = [[TYPE_ANY]]
            args   = BaseMethod.parse(text, METHOD_NAME, format)

            id = args[0].single_line

            return IDMethod.new(id)
        end

        #中間コードに変換する
        def to_hash()

            result = @id.nil?() ? @hash_empty : @id
            return result
        end
    end
end
