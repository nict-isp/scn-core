# -*- coding: utf-8 -*-
require_relative './base_method'

module DSN

    #= JoinMethodメソッドクラス
    # DSN記述のjoinメソッドを解析する。
    #
    #@author NICT
    #
    class JoinMethod < BaseMethod
        # メソッド名
        METHOD_NAME = "join"

        def initialize(delay, virtual, expr, srcs)
            @delay   = delay
            @srcs    = srcs
            @virtual = virtual
            @expr    = expr
        end

        #マージメソッドに対応した文字列か判定する。
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # mergeメソッド構文を解析する。
        #
        #@param [DSNtext] text メソッドの文字列
        #@return [Array<String>] メソッドの引数の配列
        #@raise [DSNFormatError] メソッドとして,正しい形式でない場合
        #
        def self.parse(text)
            # 可変長引数を含むため、まずはフォーマット指定なしで引数の数を取得する。
            format = nil
            args = BaseMethod.parse(text, METHOD_NAME, format)
            if args.size < 3
                raise DSNFormatError.new(ErrorMessage::ERR_JOIN_METHOD, text)
            end
            # 引数の長さに応じたフォーマットを設定し、再parseする。
            format = [[TYPE_INTEGER], [TYPE_DATANAME], [TYPE_STRING]]
            # 可変長引数を追加
            (args.size - 3).times do
                format << [TYPE_DATANAME]
            end
            args = BaseMethod.parse(text, METHOD_NAME, format)

            delay   = args[0].single_line
            virtual = args[1].single_line
            expr    = args[2].single_line
            srcs    = args.drop(3).map {|arg| arg.single_line} 

            return JoinMethod.new(delay, virtual, expr, srcs)
        end

        #中間コードに変換する。
        def to_hash()
            return {
                KEY_TYPE         => METHOD_NAME,
                KEY_DELAY        => @delay,
                KEY_MERGE_SRC    => @srcs,
                KEY_VIRTUAL_NAME => @virtual,
                KEY_VIRTUAL_EXPR => @expr,
            }
        end
    end
end
