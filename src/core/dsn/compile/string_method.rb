# -*- coding: utf-8 -*-
require_relative './base_method'

module DSN

    #= StringMethodメソッドクラス
    # DSN記述のstringメソッドを解析する。
    #
    #@author NICT
    #
    class StringMethod < BaseMethod
        # メソッド名
        METHOD_NAME = "string"

        def initialize(data_name, operator, param)
            @data_name = data_name
            @operator  = operator
            @param     = param
        end

        #フィルタメソッドに対応した文字列か判定する。
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # stringメソッド構文を解析する。
        #
        #@param [DSNtext] text メソッドの文字列
        #@return [Array<String>] メソッドの引数の配列
        #@raise [DSNFormatError] メソッドとして,正しい形式でない場合
        #
        def self.parse(text)
            format = nil
            args = BaseMethod.parse(text, METHOD_NAME, format)

            if args.size() < 2
                raise DSNFormatError.new(ErrorMessage::ERR_STRING_FORMAT, text)
            end

            param = []
            data_name = args[0].single_line
            operator  = args[1].single_line

            # オペレーション毎に引数が異なる。
            case operator
            when "removeBlanks", "lowerCase", "upperCase", "alphaReduce", "numReduce"
                if args.size() != 2
                    raise DSNFormatError.new(ErrorMessage::ERR_STRING_FORMAT0, text)
                end

            when "removeSpecialChars", "concat"
                if args.size() != 3
                    raise DSNFormatError.new(ErrorMessage::ERR_STRING_FORMAT1, text)
                end
                # 文字列の前後に強制的に付与される「"(ダブルクォート)」を削除する。
                param << args[2].single_line.slice(/[^"].*/).slice(/.*[^"]/)

            when "replace", "regexReplace"
                if args.size() != 4
                    raise DSNFormatError.new(ErrorMessage::ERR_STRING_FORMAT2, text)
                end
                param << args[2].single_line.slice(/[^"].*/).slice(/.*[^"]/)
                param << args[3].single_line.slice(/[^"].*/).slice(/.*[^"]/)
            else
                raise DSNFormatError.new(ErrorMessage::ERR_STRING_FORMAT, text)
            end

            return StringMethod.new(data_name, operator, param)
        end

        #中間コードに変換する。
        def to_hash()
            return {
                KEY_STRING => {
                    KEY_STRING_DATA_NAME => @data_name,
                    KEY_OPERATOR         => @operator,
                    KEY_PARAM            => @param
                }}
        end

    end

end
