#-*- coding: utf-8 -*-
require_relative './sign_condition'
require_relative './event_condition'
require_relative './like_method'
require_relative './range_method'
require_relative './not_modifier'

module DSN

    #= 条件判定についての中間コード化および結果判定をおこなうクラス。
    #
    #@author NICT
    #
    class ConditionFactory

        # 中間コードに変換する。
        #
        #@param [DSNText] expression 中間コードに変換する対象の文字列
        #@return [DSNText] result 各構文による処理結果
        #@raise [DSNFormatError] 不適切なConditionが入力された場合
        #
        def self.parse(expression)
            case
            when SignCondition.match?(expression)
                #不等号の場合
                result = SignCondition.parse(expression)
            when EventCondition.match?(expression)
                result = EventCondition.parse(expression)
            when LikeMethodCondition.match?(expression)
                result = LikeMethodCondition.parse(expression)
            when RangeMethodCondition.match?(expression)
                result = RangeMethodCondition.parse(expression)
            when NotModifierCondition.match?(expression)
                result = NotModifierCondition.parse(expression)
            else
                #Conditionとして不適切な場合はエラー
                raise DSNInternalFormatError.new(ErrorMessage::ERR_NO_CONDITION)
            end
            return result
        end

        # 指定したデータが条件を満たしているかどうかを判定する。
        #
        #@param [String] key 条件判定対象のデータ名
        #@param [Array<String>] 判定条件, 閾値
        #@param [Hash<String>] 条件判定対象のデータ名をキーに、値として、条件判定対象の値を持つハッシュ。 
        #@return [Boolean] 判定条件を満たしている場合は、true,満たしていない場合はfalse
        #
        def self.ok?(key, values, data)
            sign, threshold = values
            case sign
            when REG_SIGN_FORMAT
                #不等号の場合
                result = SignCondition.ok?(key, values, data)
            when KEY_RANGE
                result = RangeMethodCondition.ok?(key, values, data)
            when KEY_LIKE
                result = LikeMethodCondition.ok?(key, values, data)
            when KEY_NOT
                result = NotModifierCondition.ok?(key, values, data)
            else
                result = false
            end
            return result
        end
    end
end
