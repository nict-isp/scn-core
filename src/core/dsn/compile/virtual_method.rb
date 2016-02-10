# -*- coding: utf-8 -*-
require_relative './base_method'

module DSN

    #= VirtualMethodメソッドクラス
    # DSN記述のvirtualメソッドを解析する。
    #
    #@author NICT
    #
    class VirtualMethod < BaseMethod
        # メソッド名
        METHOD_NAME = "virtual"

        def initialize(virtual, expr)
            @virtual = virtual
            @expr    = expr
        end

        #マージメソッドに対応した文字列か判定する。
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # virtualメソッド構文を解析する。
        #
        #@param [DSNtext] text メソッドの文字列
        #@return [Array<String>] メソッドの引数の配列
        #@raise [DSNFormatError] メソッドとして,正しい形式でない場合
        #
        def self.parse(text)
            format  = [[TYPE_DATANAME], [TYPE_STRING]]
            args    = BaseMethod.parse(text, METHOD_NAME, format)
            virtual = args[0].single_line 
            expr    = args[1].single_line

            return VirtualMethod.new(virtual, expr)
        end

        #中間コードに変換する。
        def to_hash()
            return {
                KEY_VIRTUAL => {
                    KEY_VIRTUAL_NAME => @virtual,
                    KEY_VIRTUAL_EXPR => @expr,
                }
            }
        end
    end
end
