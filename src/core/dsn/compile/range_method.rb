#-*- coding: utf-8 -*-
require_relative './condition'

module DSN

    #= rangeメソッドを中間コード化、および
    #  中間コードをもとに条件判定をおこなう。
    #
    #@author NICT
    #
    class RangeMethodCondition < Condition
        METHOD_NAME = "range"

        #RangeMethodCondtionの対象文字列かどうかを判定する。
        #
        #@param [DSNText] 検査対象文字列
        #@return [Boolean] 対象ならtrue,そうでなければfalse
        #
        def self.match?(expression)
            return BaseMethod::match?(expression,METHOD_NAME)
        end

        #文字列からインスタンスを作成する。
        #
        #@param [DSNText] expression 変換対象の文字列
        #@return [RangeMethodCondtion] SignCondtionのインスタンス
        #@raise [DSNFormatError] メソッドの入力として不適切な場合
        #
        def self.parse(expression)
            format = [[TYPE_DATANAME], [TYPE_INTEGER, TYPE_FLOAT, TYPE_TIME, TYPE_STRING], [TYPE_INTEGER, TYPE_FLOAT, TYPE_TIME, TYPE_STRING]]

            args_data = BaseMethod.parse(expression, METHOD_NAME, format)

            data_name = args_data.shift
            data_name_string = data_name.single_line
            args_data_array = args_data.map{|arg| arg.single_line}

            min = args_data_array[0]
            max = args_data_array[1]

            # min, maxの型が異なる場合はエラーとする
            # ただし、整数と実数の違いは許容する
            # 整数の場合は一旦実数へ変換
            temp_min = min # 一旦退避
            temp_max = max
            if min.is_a?(Integer)
                min = min.to_f
            end
            if max.is_a?(Integer)
                max = max.to_f
            end

            # 文字列と実数の組み合わせをエラーとする
            unless min.kind_of?(max.class)
                min = temp_min # 表示用に書き戻す
                max = temp_max
                msg = "min: #{min.class}, max: #{max.class}"
                raise DSNFormatError.new(ErrorMessage::ERR_RANGE_TYPE, expression, msg)
            end

            # min > maxとなっていた場合はエラーとする
            if min > max
                min = temp_min # 表示用に書き戻す
                max = temp_max
                msg = "min: #{min}, max: #{max}"
                raise DSNFormatError.new(ErrorMessage::ERR_RANGE_BACK, expression, msg)

            end

            return RangeMethodCondition.new(data_name_string,METHOD_NAME, args_data_array)
        end

        #指定された中間コードのデータが条件を満たしているか判定する。
        #
        #@param [String] key 条件判定対象のデータ名
        #@param [Array<String>] 判定条件, 閾値
        #@param [Hash<String>] 条件判定対象のデータ名をキーに、
        #                      値として、条件判定対象の値を持つハッシュ
        #@return [Boolean] 判定条件を満たしている場合は、true、
        #                  満たしていない場合は、false
        #                  整数と実数の比較は問題ないが、
        #                  判定対象とデータの型が異なる場合は、false
        #
        def self.ok?(key, values, data)
            sign, min, max = values
            variable = data[key]

            # 整数と実数の比較を実施するため、実数に変換する
            if min.is_a?(Integer)
                min = min.to_f
            end
            if max.is_a?(Integer)
                max = max.to_f
            end
            if variable.is_a?(Integer)
                variable = variable.to_f
            end

            if variable.kind_of?(min.class)
                case sign
                when METHOD_NAME
                    #閾値の範囲内かどうか判定する。
                    if min <= variable && variable < max
                        result = true
                    else
                        result = false
                    end
                else
                    raise ArgumentError, "invalid method(=#{sign})"
                end
            else
                # 期待値とデータの型が異なる場合はfalseを返す
                result = false
            end
        end
    end
end
