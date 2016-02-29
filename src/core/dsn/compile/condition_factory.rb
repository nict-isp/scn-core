#-*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative './sign_condition'
require_relative './event_condition'
require_relative './like_method'
require_relative './range_method'
require_relative './not_modifier'

module DSN

    #= Classes for intermediate encoding and result judgment about the condition determination.
    #
    #@author NICT
    #
    class ConditionFactory

        #It is converted into an intermediate code.
        #
        #@param [DSNText] expression  String of the object to be converted to an intermediate code
        #@return [DSNText] result The result of processing by each syntax
        #@raise [DSNFormatError] Invalid condition has been input
        #
        def self.parse(expression)
            case
            when SignCondition.match?(expression)
                # In the case of inequality
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
                # Invalid case as Condition is error
                raise DSNInternalFormatError.new(ErrorMessage::ERR_NO_CONDITION)
            end
            return result
        end

        # It determines whether or not the specified data meets the conditions.
        #
        #@param [String]        key     Data name of the condition determination target
        #@param [Array<String>] values  Judgment condition, threshold
        #@param [Hash<String>]  data    Hash with a data name of the condition determination object as a key, 
        #                               the value of the condition determination object as a value.
        #@return [Boolean] True when it meet the judgment conditions, false when it does not meet.
        #
        def self.ok?(key, values, data)
            sign, threshold = values
            case sign
            when REG_SIGN_FORMAT
                # In the case of inequality
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
