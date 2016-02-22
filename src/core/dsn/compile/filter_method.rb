# -*- coding: utf-8 -*-
require_relative './base_method'
require_relative './conditions'

module DSN

    #= FilterMethod class
    # To analyze the filter method of DSN description.
    #
    #@author NICT
    #
    class FilterMethod < BaseMethod
        METHOD_NAME = "filter"

        #@return [Conditions] Conditions that are set in the method
        attr_reader :conditions

        #@param [DSNText] conditions  String of filter condition
        #
        def initialize(conditions)
            @conditions = Conditions.parse(conditions)
        end

        # It determines whether the character string corresponding to the filter method.
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # To analyze the filter method syntax.
        #
        #@param [DSNText] text  String of method
        #@return [Array<String>] Array of arguments of the method
        #
        def self.parse(text)
            format = [[TYPE_ANY]]
            args   = BaseMethod.parse(text, METHOD_NAME, format)

            return FilterMethod.new(args[0])
        end

        # It is converted into an intermediate code.
        def to_hash()
            return { KEY_FILTER => @conditions.to_hash }
        end
    end
end
