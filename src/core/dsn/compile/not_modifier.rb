#-*- coding: utf-8 -*-
require_relative './condition'

module DSN

    #= likeメソッドを中間コード化、および
    #  中間コードをもとに条件判定をおこなう。
    #
    #@author NICT
    #
    class NotModifierCondition < Condition
        METHOD_NAME = "not"

        #NotModifierCondtionの対象文字列かどうかを判定する。
        #
        #@param [DSNText] 検査対象文字列 
        #@return [Boolean] 対象ならtrue,そうでなければfalse
        #
        def self.match?(expression)
            reg = REG_NOT_FORMAT.match(expression.single_line)
            if reg.nil?
                return nil
            end
            return true
        end

        #文字列からインスタンスを作成する。
        #notを除いた文字列をConditionFactoryのparse処理に入力する
        #
        #@param [DSNText] expression 変換対象の文字列
        #@return [NotModifierCondition] NotModifierConditionのインスタンス
        #@raise [DSNFormatError] not修飾子が無効なクラスオブジェクトの場合
        #
        def self.parse(expression)
            # 1行文字列からnotを削除
            temp_single_line =  expression.single_line.gsub(/^not\s+/,"")

            # ConditionFactory.parseへ入力
            temp_expression = DSNText.new(expression.text, expression.line_offset, temp_single_line)
            temp_result = ConditionFactory.parse(temp_expression)

            # 中間コード相当の配列作成
            ret_threshold =  [temp_result.sign].concat(temp_result.threshold)

            return NotModifierCondition.new(temp_result.data_name, METHOD_NAME, [ret_threshold])
        end

        #指定された中間コードのデータが条件を満たしているか判定する。
        #not修飾子を外した中間コードを条件チェックし
        #返り値を反転させる。
        #
        #@param [String] key 条件判定対象のデータ名
        #@param [Array<String>] 判定条件, 閾値
        #@param [Hash<String>] 条件判定対象のデータ名をキーに、値として、条件判定対象の値を持つハッシュ 
        #@return [Boolean] 判定条件を満たしている場合は、true、満たしていない場合は、false
        #@raise [ArgumentError] not修飾子でないデータ入力
        #
        def self.ok?(key, values, data)
            sign, threshold = values
            msg = data[key]
            result = false
            case sign
            when METHOD_NAME
                # not修飾子を外した中間コードを再度判定
                result = ConditionFactory.ok?(key, values[1], data)
                return !result
            else
                raise ArgumentError
            end
            return result
        end
    end
end
