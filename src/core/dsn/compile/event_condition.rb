#-*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative './sign_condition'
require_relative './dsn_define'

module DSN

    #= Processing of inequality to intermediate encoding. In addition, 
    # the condition for determining based on the intermediate code.
    #
    #@author NICT
    #
    class EventCondition < SignCondition

        # Determines whether or not the target string of EventCondtion.
        #
        #@param [DSNText] expression  Inspected string
        #@return [Boolean] True if target, false otherwise
        #
        def self.match?(expression)
            if expression.single_line =~ REG_EVENTS_CONDITION
                return true
            end
            return false
        end

        # To create an instance from a string.
        #
        #@param [DSNText] expression  String to be converted
        #@return [EventCondition] Instance of EventCondition
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
