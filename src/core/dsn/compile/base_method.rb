# -*- coding: utf-8 -*-
require_relative './dsn_text'
require_relative './dsn_define'
require_relative './error_message'
require_relative '../../utils'

module DSN

    #= BaseMethodクラス
    # DSN記述のメソッドを解析する。
    #
    #@author NICT
    #
    class BaseMethod

        #引数で指定したメソッドのメソッド名と引数を返す。
        #
        #@param [DSNText] text 対象の文字列
        #@return [Array<DSNText>] メソッド名、引数
        #
        def self.match(method_text)
            reg = REG_METHOD_FORMAT.match(method_text.single_line)
            if reg.nil?
                return nil
            end
            return DSNText.new(method_text.text,method_text.line_offset,reg[CAP_INDEX_METHOD_NAME]),
            DSNText.new(method_text.text,method_text.line_offset,reg[CAP_INDEX_METHOD_ARG])
        end

        #引数で指定したメソッドか判定する。
        #
        #@param [DSNText] text 対象の文字列
        #@param [String] method_name メソッド名
        #@return [Boolean] 対象のメソッドならばtrueを返す。
        #
        def self.match?(method_text,method_name)
            method, attr = match(method_text)
            if method.nil?
                return false
            end
            return ( method.single_line == method_name )
        end

        # メソッド[メソッド名(引数1, 引数2)の形式]を解析する。
        #@param [DSNText] text メソッドの文字列
        #@param [String] method_name メソッド名
        #@param [Array<String>] format メソッドの引数の形式
        #@return [Array<DSNText>] argument メソッドの引数の配列
        #@raise [DSNFormatError] メソッドとして、正しい形式でない場合
        #
        def self.parse(dsn_text, method_name, format=nil)

            #methodの全体のフォーマットをチェックする。
            check_format(dsn_text,method_name)

            name, argument_line = match(dsn_text)
            arguments = DSNText.split_comma(argument_line)

            # split結果に対して、メソッド引数の型変換を行う
            # formatの指定がない場合は実施しない
            unless format.nil?
                arguments = convert_argument_format(arguments, format, method_name)
            end

            return arguments
        end

        #メソッドのフォーマットをチェックする。(引数部分を除く)
        #
        #@param [DSNText] text メソッドの文字列
        #@param [String] method_name メソッド名
        #@raise [DSNFormatError] メソッドとして、正しい形式でない場合
        #
        def self.check_format(text,method_name)
            #メソッドの文字列の先頭がメソッド名と一致していること。
            #メソッド名の次の文字が「(」であること。
            #メソッド名の最後の文字が「)」であること。
            if text.single_line =~ /^#{method_name}\(#{REG_METHOD_ARG}\)$/
                #一致していれば正常(何もしない）
            else
                raise DSNFormatError.new(ErrorMessage::ERR_FORMAT_METHOD, text)
            end

        end

        #引数の型を判定し、変換する。
        #
        #@param [String] param 判定対象の文字列
        #@return [datatype] 文字列, 整数, 実数いずれかの型
        #@raise [DSNFormatError] 適切でない文字列の場合
        #@note 10e+05 のような指数表記はサポートしない
        #
        def self.convtype(param)
            if param =~ /^-?\d*$/ # 整数
                return param.to_i
            elsif param =~ /^-?\d+\.\d+$/ # 実数
                return param.to_f
            elsif param =~ /^\"(.*)\"$/ # 文字列
                return $1.to_s
            else
                # 小数点が複数あったり
                # ""で囲まれていない文字列はエラー
                msg = "#{ErrorMessage::ERR_ARGUMENT_FORMAT}\ninput: #{param}"
                raise DSNInternalFormatError.new(msg)
            end
        end

        #時刻の文字列フォーマットを確認する。
        #
        #@param [String] param 判定対象の文字列
        #@return [datatype] 文字列型
        #@raise [DSNFormatError] 時刻として不適切な文字列の場合
        #
        def self.time_format_check(param)
            # 時刻が文字列形式で与えられているか確認
            time = BaseMethod.convtype(param)
            if time.is_a?(String)
                # 時刻変換できない場合はエラーとする
                if time_to_sec(time).is_a?(Fixnum)
                    return time
                end
            end
            # ここへ来る場合はすべてエラー
            msg = "#{ErrorMessage::ERR_TIMEDATA_FORMAT}\ninput: #{param}"
            raise DSNInternalFormatError.new(msg)
        end

        #データ名の文字列フォーマットを確認する。
        #
        #@param [String] param 判定対象の文字列
        #@return [datatype] 文字列型
        #@raise [DSNFormatError] 適切でない文字列の場合
        #
        def self.dataname_check(param)
            if param =~ /^\w+$/ # アルファベットと数字、_のみ可
                return param.to_s
            else

                msg = "#{ErrorMessage::ERR_DATANAME_FORMAT}\ninput: #{param}"
                raise DSNInternalFormatError.new(msg)
            end
        end

        # パース処理後のDSNtextに含まれるメソッド引数(single_line部)の
        # フォーマットを変更する
        #
        #@param [Array<DSNtext>] arguments パース後のメソッド引数
        #@param [Array] exp_format 各引数として期待される型
        #                TYPE_DATANAME: データ名
        #                TYPE_INTEGER : 整数
        #                TYPE_FLOAT   : 実数
        #                TYPE_STRING  : 文字列
        #                TYPE_TIME    : 時刻
        #                TYPE_ANY     : チェックしない
        #                以上を2次元配列で指定する
        #   ex. 引数の期待値が「データ名」「整数または実数」「文字列」
        #       arguments = [[TYPE_DATANAME], [TYPE_INTEGER, TYPE_FLOAT],[TYPE_STRING]]
        #@return [Array<DSNtext>] ret @single_lineが適切なオブジェクト型に変換されたもの
        #@raise [DSNFormatError] 期待される型とパース後の型が一致しない
        #
        def self.convert_argument_format(arguments, exp_format, method_name)

            # 期待される引数の数とパース後の引数の数が一致するか確認
            if arguments.length != exp_format.length
                # 一致しない場合はエラー、メソッドの正しいフォーマットを表示
                msg = "#{ErrorMessage::ERR_ARGUMENTS}\n#{ErrorMessage::FORMAT_HASH[method_name]}"
                raise DSNInternalFormatError.new(msg)
            end

            ret = []
            count = 1

            # パース後の引数が期待される型か確認する
            # 型の期待値は複数取り得るため、最後までマッチがない場合
            # のみエラーとする
            arguments.zip(exp_format) do | arg, exp |
                out = nil
                exp.each do | type |
                    begin
                        out = try_convert(arg.single_line, type)
                        break
                    rescue
                    end
                end

                # 期待値にマッチした場合はDSNTextを作成
                # マッチしなかった場合エラー
                if out != nil
                    dsn = DSNText.new(arg.text, arg.line_offset, out)
                else
                    # 問題の引数が何で何番目だったか、
                    # 期待される型が何だったかをエラーメッセージに含める
                    case count
                    when 1
                        ordinal = "1st"
                    when 2
                        ordinal = "2nd"
                    when 3
                        ordinal = "3rd"
                    else
                        ordinal = "#{count}th"
                    end
                    error_msg = "The #{ordinal} argument \"#{arg.single_line}\" does not have the expected data format: #{exp}"
                    msg = "#{ErrorMessage::ERR_DATA_TYPE}\n#{error_msg}"
                    raise DSNInternalFormatError.new(msg)
                end

                # 出力配列に格納
                ret << dsn
                count += 1
            end
            return ret
        end

        #入力文字列の型を変換し、期待値と照合する
        #
        #@param [String] param メソッドの文字列
        #@param [String] exp paramに対する期待値
        #@return [Integer/Float/String] 対応する型
        #@raise [DSNFormatError] 正しい形式でない場合
        #
        def self.try_convert(param, exp)
            case exp
            when TYPE_DATANAME
                out = BaseMethod.dataname_check(param)
            when TYPE_INTEGER
                out =  BaseMethod.convtype(param)
                # 変換結果が期待値と異なる場合はエラー
                unless out.is_a?(Integer)
                    raise ArgumentError
                end
            when TYPE_FLOAT
                out =  BaseMethod.convtype(param)
                # 変換結果が期待値と異なる場合はエラー
                unless out.is_a?(Float)
                    raise ArgumentError
                end
            when TYPE_STRING
                out =  BaseMethod.convtype(param)
                # 変換結果が期待値と異なる場合はエラー
                unless out.is_a?(String)
                    raise ArgumentError
                end
            when TYPE_TIME
                out =  BaseMethod.time_format_check(param)
            when TYPE_ANY
                # anyが指定された場合は常に問題なし
                out = param
            else
                # DSN記述のエラーではなく、メソッド中で
                # 誤った型が指定されている場合はエラー
                raise "Specified TYPE is not correct."
            end
            return out
        end

        #入力文字列が予約語かどうかを確認する
        #
        #@param [String] param 判定対象の文字列
        #@return [Boolian] True: 予約語, False: 予約語でない
        #
        def self.reserved?(param)
            ret = RESERVED_ARRAY.any? {|word| word == param}
            return ret
        end

    end
end
