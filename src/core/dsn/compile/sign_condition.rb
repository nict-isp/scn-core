#-*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative './condition'
require_relative './dsn_define'

module DSN

    #= Processing of inequality to intermediate encoding. In addition, 
    # the condition for determining based on the intermediate code.
    #
    #@author NICT
    #
    class SignCondition < Condition

        # Determines whether or not the target string of SignCondition.
        #
        #@param [DSNText] expression  Inspected string
        #@return [Boolean] True if target, false otherwise
        #
        def self.match?(expression)
            if expression.single_line =~ /(?<name>\w+)\s*(?<sign>#{REG_SIGN})\s*(?<threshold>.+)/
                return true
            end
            return false
        end

        # To create an instance from a string.
        #
        #@param [DSNText] expression  String to be converted
        #@return [SignCondtion] Instance of SignCondtion
        #
        def self.parse(expression)
            reg = /(?<name>\w+)\s*(?<sign>#{REG_SIGN})\s*(?<threshold>.+)/.match(expression.single_line)

            # The left-hand side (name part) to confirm that it is a type of data name.
            dataname = BaseMethod.dataname_check(reg[:name])

            # To verify the type of the right-hand side (threshold part).
            conved_type = BaseMethod.convtype(reg[:threshold])

            # The inequality part to a string type.
            sign = reg[:sign].to_s

            return SignCondition.new(dataname, sign, [conved_type])
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
            variable = data[key]

            # If the value is integer or real number, to convert to a real number for comparison.
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
