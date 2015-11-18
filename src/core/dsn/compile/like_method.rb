#-*- coding: utf-8 -*-
require_relative './condition'

module DSN

    #= likeメソッドを中間コード化、および
    #  中間コードをもとに条件判定をおこなう。
    #
    #@author NICT
    #
    class LikeMethodCondition < Condition
        METHOD_NAME = "like"

        #LikeMethodCondtionの対象文字列かどうかを判定する。
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
        #@return [LikeMethodCondtion] SignCondtionのインスタンス
        #
        def self.parse(expression)
            format = [[TYPE_DATANAME], [TYPE_STRING]]
            data_name, regex = BaseMethod.parse(expression, METHOD_NAME, format)
            data_name_string = data_name.single_line
            regex_string = regex.single_line

            return LikeMethodCondition.new(data_name_string,METHOD_NAME, [regex_string])
        end

        #指定された中間コードのデータが条件を満たしているか判定する。
        #
        #@param [String] key 条件判定対象のデータ名
        #@param [Array<String>] 判定条件, 閾値
        #@param [Hash<String>] 条件判定対象のデータ名をキーに、値として、条件判定対象の値を持つハッシュ 
        #@return [Boolean] 判定条件を満たしている場合は、true、満たしていない場合は、false
        #
        def self.ok?(key, values, data)
            sign, threshold = values
            msg = data[key]
            result = false
            case sign
            when METHOD_NAME
                if msg =~ Regexp.new(threshold)
                    result = true
                end
            else
                raise ArgumentError, "invalid method(=#{sign})"
            end
            return result
        end
    end

end
