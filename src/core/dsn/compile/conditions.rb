#-*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative '../../utils'
require_relative './condition_factory'
require_relative './dsn_text'

module DSN

    #=Executing an analysis of the "conditions" syntax.
    #
    #@author NICT
    #
    class Conditions

        #@param [DSNText]       expression  String of the subject
        #@param [Array<String>] and         String, which is connected by "and" syntax
        #@param [Array<String>] or          String, which is connected by "or" syntax
        #@param [String]        condtion    The final conditions that are connected by "and" and "or"
        #
        def initialize(expression)
            @expression = expression
            @and        = []
            @or         = []
            @condition  = nil
        end

        #To create an instance from a string.
        #
        #@param [DSNText] expression  String of the subject
        #@return [Conditions] An instance of the Condition class
        #
        def self.parse(expression)
            condition = Conditions.new(expression)
            condition._parse()
            return condition
        end

        #Internal process for generating an instance from a string
        def _parse()

            # Return If the character string can be divided by "||" or "&&"
            @or = _split_conditions("||")
            return if @or.size > 0

            @and = _split_conditions("&&")
            return if @and.size > 0

            # If the entire string can not be split it has been enclosed in parentheses,
            # to implement the re-division processing to remove the parentheses.
            if(/^\(.*\)$/ =~ @expression.single_line)
                _trim_brackets()
                _parse()
            else

                # Already split up a single conditional expression
                @condition = ConditionFactory.parse(@expression)
            end
        end

        #Division processing of the conditional expression
        #
        #@param [String] sign  The sign of the split conditions("&" or "|" )
        #@return [Array<Conditions>] Array of Conditions instance
        #
        def _split_conditions(sign)
            conditions = []

            log_debug{"in:" + @expression.single_line}
            #            expressions = split_conditions(@expression.single_line, sign).map{|cond|
            expressions = DSNText.split(@expression.single_line, sign).map{|cond|
                log_debug{"out:" + cond}
                DSNText.new(@expression.text, @expression.line_offset, cond)
            }
            # If the condition is not divided, without that fall under the sign of the argument.
            if expressions.length == 1
                return conditions
            end

            expressions.each do |expression|
                # Recursive call until a single conditional expression.
                conditions << Conditions.parse(expression)
            end
            return conditions
        end

        #To remove the beginning and end of the brackets.
        def _trim_brackets()
            log_debug(){"#{@expression.single_line}"}
            reg = /^\((?<exp>.+)\)$/.match(@expression.single_line)
            log_debug(){"#{reg}"}
            if reg.nil? == true
                return
            else
                @expression = DSNText.new(@expression.text, @expression.line_offset, reg[:exp])
            end
        end

        #It is converted into an intermediate code
        #
        #@return [Hash<String,Object>] Intermediate code of conditional expression 
        #
        def to_hash()
            return {"-or"  => @or.map{ |condition| condition.to_hash() }}   if @or.size > 0
            return {"-and" => @and.map{ |condition| condition.to_hash() }}  if @and.size > 0
            return @condition.to_hash
        end

        #To get all of the data names used in conditional expression
        #
        #@return [Array<String>] Data name in the conditional expression
        #
        def get_data_names()
            return @or.inject([]){ |parent, condition| parent.concat condition.get_data_names } if @or.size > 0
            return @and.inject([]){ |parent, condition| parent.concat condition.get_data_names }  if @and.size > 0
            return [@condition.data_name]
        end

        #It determines whether or not the data specified in the argument meets the conditional expression.
        #
        #@param [Condtions]            conditions  Determination target of the conditional expression
        #@param [Hash<String,String>]  data        Determination target of data
        #@return [Boolean] True when it meet the conditions, false otherwise.
        #
        def self.ok?(conditions, data)
            conditions.each do |key, values|
                case key
                when "-and"
                    result = values.all?{ |condition| self.ok?(condition, data) }
                when "-or"
                    result = values.any?{ |condition| self.ok?(condition, data) }
                else
                    result = ConditionFactory.ok?(key, values, data)
                end
                log_debug() { "conditions = #{conditions}, data = #{data}, result = #{result}" }

                return result   # Hash of the conditional expression has only one element
            end
        end
    end
end
