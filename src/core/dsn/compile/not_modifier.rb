#-*- coding: utf-8 -*-
require_relative './condition'

module DSN

    #= The "not" method to intermediate encoding, and determining the condition
    #  of the intermediate code to the original.
    #
    #@author NICT
    #
    class NotModifierCondition < Condition
        METHOD_NAME = "not"

        # Determines whether or not the target string of NotModifierCondtion.
        #
        #@param [DSNText] expression  Inspected string 
        #@return [Boolean] True when target, false otherwise
        #
        def self.match?(expression)
            reg = REG_NOT_FORMAT.match(expression.single_line)
            if reg.nil?
                return nil
            end
            return true
        end

        # To create an instance from a string.
        # To enter a string excluding the "not" in the analysis process of ConditionFactory.
        #
        #@param [DSNText] expression  String to be converted
        #@return [NotModifierCondition] Instance of NotModifierCondition
        #@raise [DSNFormatError] class object that is invalid for "not" qualifier
        #
        def self.parse(expression)
            # To remove the "not" from the first row string.
            temp_single_line =  expression.single_line.gsub(/^not\s+/,"")

            # Input to "ConditionFactory.parse".
            temp_expression = DSNText.new(expression.text, expression.line_offset, temp_single_line)
            temp_result = ConditionFactory.parse(temp_expression)

            # To create an array of intermediate code equivalent.
            ret_threshold =  [temp_result.sign].concat(temp_result.threshold)

            return NotModifierCondition.new(temp_result.data_name, METHOD_NAME, [ret_threshold])
        end

        # Determining data for the specified intermediate code is whether it meets the conditions.
        # To check the condition of the intermediate code it remove the "not" qualifier.
        #
        #@param [String]        key     Data name of the condition determination target
        #@param [Array<String>] values  Judgment condition, threshold
        #@param [Hash<String>]  data    Hash with a data name of the condition determination object as a key, 
        #                               the value of the condition determination object as a value.
        #@return [Boolean] True when it meet the judgment conditions, false when it does not meet.
        #@raise [ArgumentError] Data input is not a not qualifiers
        #
        def self.ok?(key, values, data)
            sign, threshold = values
            msg = data[key]
            result = false
            case sign
            when METHOD_NAME
                # Determining the intermediate code remove the "not" qualifiers again.
                result = ConditionFactory.ok?(key, values[1], data)
                return !result
            else
                raise ArgumentError
            end
            return result
        end
    end
end
