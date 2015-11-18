#-*- coding: utf-8 -*-
require_relative './sign_condition'
require_relative './dsn_define'

module DSN

    #= 不等号の処理を中間コード化、および
    #  中間コードをもとに条件判定をおこなう。
    #
    #@author NICT
    #
    class EventCondition < SignCondition

        #EventCondtionの対象文字列かどうかを判定する。
        #
        #@param [DSNText] 検査対象文字列 
        #@return [Boolean] 対象ならtrue,そうでなければfalse
        #
        def self.match?(expression)
            if expression.single_line =~ REG_EVENTS_CONDITION
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
            reg = REG_EVENTS_CONDITION.match(expression.single_line)
            case reg[:state]
            when "on"
                state_on = true
            when "off"
                state_on = false
            end
            return EventCondition.new(reg[:event_name],REG_EVENTS_SIGN,[state_on])
        end
    end
end
