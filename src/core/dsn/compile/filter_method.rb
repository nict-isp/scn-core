# -*- coding: utf-8 -*-
require_relative './base_method'
require_relative './conditions'

module DSN

    #= FilterMethodメソッドクラス
    # DSN記述のfilterメソッドを解析する。
    #
    #@author NICT
    #
    class FilterMethod < BaseMethod
        # メソッド名
        METHOD_NAME = "filter"

        #@return [Conditions] メソッド内で設定されている条件
        attr_reader :conditions

        #@param [DSNText] conditions フィルタ条件を示す文字列
        #
        def initialize(conditions)
            @conditions = Conditions.parse(conditions)
        end

        #フィルタメソッドに対応した文字列か判定する。
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # filterメソッド構文を解析する。
        #
        #@param [DSNText] text メソッドの文字列
        #@return [Array<String>] メソッドの引数の配列
        #
        def self.parse(text)
            # フォーマットの定義
            format = [[TYPE_ANY]]
            args = BaseMethod.parse(text, METHOD_NAME, format)
            return FilterMethod.new(args[0])
        end

        #中間コードに変換する
        def to_hash()
            return { KEY_FILTER => @conditions.to_hash }
        end
    end
end
