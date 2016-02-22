#-*- coding: utf-8 -*-
require_relative './condition'

module DSN

    #= A like method to intermediate encoding. In addition, 
    # the condition for determining based on the intermediate code.
    #
    #@author NICT
    #
    class LikeMethodCondition < Condition
        METHOD_NAME = "like"

        # Determines whether or not the target string of LikeMethodCondtion.
        #
        #@param [DSNText] expression  Inspected string
        #@return [Boolean] True if target, false otherwise
        #
        def self.match?(expression)
            return BaseMethod::match?(expression,METHOD_NAME)
        end

        # To create an instance from a string.
        #
        #@param [DSNText] expression  String to be converted
        #@return [LikeMethodCondtion] Instance of LikeMethodCondtion
        #
        def self.parse(expression)
            format = [[TYPE_DATANAME], [TYPE_STRING]]
            data_name, regex = BaseMethod.parse(expression, METHOD_NAME, format)
            data_name_string = data_name.single_line
            regex_string = regex.single_line

            return LikeMethodCondition.new(data_name_string,METHOD_NAME, [regex_string])
        end

        # It determines whether the data of the specified intermediate code meets the conditions.
        #
        #@param [String]        key     Data name of the target is determined conditions
        #@param [Array<String>] values  Judgment condition, threshold
        #@param [Hash<String>]  data    Hash with a data name of the condition determination target key,
        #                               and with the value of the condition determination target value.
        #@return [Boolean] If it meet the condition true, not meet the condition false
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
