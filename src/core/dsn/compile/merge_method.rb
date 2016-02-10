# -*- coding: utf-8 -*-
require_relative './base_method'

module DSN

    #= MergeMethodメソッドクラス
    # DSN記述のmergeメソッドを解析する。
    #
    #@author NICT
    #
    class MergeMethod < BaseMethod
        # メソッド名
        METHOD_NAME = "merge"

        def initialize(delay, srcs)
            @delay = delay
            @srcs  = srcs
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
            if args.size < 1
                raise DSNFormatError.new(ErrorMessage::ERR_MERGE_METHOD, text)
            end
            # 引数の長さに応じたフォーマットを設定し、再parseする。
            format = [[TYPE_INTEGER]]
            # 可変長引数を追加
            (args.size - 1).times do
                format << [TYPE_DATANAME]
            end
            args = BaseMethod.parse(text, METHOD_NAME, format)

            delay = args[0].single_line
            srcs  = args.drop(1).map {|arg| arg.single_line} 

            return MergeMethod.new(delay, srcs)
        end

        #中間コードに変換する。
        def to_hash()
            return {
                KEY_TYPE      => METHOD_NAME,
                KEY_DELAY     => @delay,
                KEY_MERGE_SRC => @srcs
            }
        end
    end
end
