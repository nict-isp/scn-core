#-*- coding: utf-8 -*-
require_relative './condition'
require_relative './dsn_define'

module DSN

    #= 不等号の処理を中間コード化、および
    #  中間コードをもとに条件判定をおこなう。
    #
    #@author NICT
    #
    class SignCondition < Condition

        #SignCondtionの対象文字列かどうかを判定する。
        #
        #@param [DSNText] 検査対象文字列 
        #@return [Boolean] 対象ならtrue,そうでなければfalse
        #
        def self.match?(expression)
            if expression.single_line =~ /(?<name>\w+)\s*(?<sign>#{REG_SIGN})\s*(?<threshold>.+)/
                return true
            end
            return false
        end

        #文字列からインスタンスを作成する。
        #
        #@param [DSNText] expression 変換対象の文字列
        #@return [SignCondtion] SignCondtionのインスタンス
        #
        def self.parse(expression)
            #match処理で分解する。
            reg = /(?<name>\w+)\s*(?<sign>#{REG_SIGN})\s*(?<threshold>.+)/.match(expression.single_line)

            # 左辺(name部)がデータ名の型であることを確認する
            dataname = BaseMethod.dataname_check(reg[:name])

            # 右辺(threshold部)の型を確認する
            conved_type = BaseMethod.convtype(reg[:threshold])

            # 不等号部分を文字列型にする
            sign = reg[:sign].to_s

            return SignCondition.new(dataname, sign, [conved_type])
        end

        #指定された中間コードのデータが条件を満たしているか判定する。
        #
        #@param [String] key 条件判定対象のデータ名
        #@param [Array<String>] values 判定条件, 閾値
        #@param [Hash<String>] data 条件判定対象のデータ名をキーに、値として、条>    件判定対象の値を持つハッシュ
        #@return [Boolean] 判定条件を満たしている場合は、true、満たしていない場合は、false
        #
        def self.ok?(key, values, data)
            sign, threshold = values
            variable = data[key]

            # 値が整数か実数の場合は、比較のため実数に変換する
            if variable.is_a?(Integer)
                variable = variable.to_f
            end
            if threshold.is_a?(Integer)
                threshold = threshold.to_f
            end

            if variable.kind_of?(threshold.class)
                case sign
                when "<="
                    result = (variable <= threshold)
                when "<"
                    result = (variable < threshold)
                when "=="
                    result = (variable == threshold)
                when "!="
                    result = (variable != threshold)
                when ">"
                    result = (variable > threshold)
                when ">="
                    result = (variable >= threshold)
                else
                    raise ArgumentError, "invalid sign(=#{sign})"
                end
            else
                result = false
            end
            return result
        end
    end

end
