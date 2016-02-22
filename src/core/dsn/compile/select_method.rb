# -*- coding: utf-8 -*-
require_relative './base_method'
require_relative './conditions'

module DSN

    #= SelectMethod class
    # To analyze the select method of DSN description.
    #
    #@author NICT
    #
    class SelectMethod < BaseMethod
        METHOD_NAME = "select"

        HASH_EMPTY = []

        #@return [Array] Intermediate code output when empty
        attr_reader :hash_empty

        #@param [Array<String>] name  Data name of the select subject
        #
        def initialize(names)
            @names      = names
            @hash_empty = HASH_EMPTY
        end

        # It determines whether the character string corresponding to the select method.
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # To analyze the select method syntax.
        #
        #@param [DSNText] text  String of method
        #@return [Array<String>] Array of arguments of the method
        #
        def self.parse(text)
            format = nil
            args = BaseMethod.parse(text, METHOD_NAME, format)

            names = []
            args.each do |arg|
                names << arg.single_line
            end

            return SelectMethod.new(names)
        end

        # It is converted into an intermediate code.
        def to_hash()

            if @names.nil?()
                result = @hash_empty
            else
                result = []
                @names.each do |name|
                    result << {KEY_SELECT_NAME => name}
                end
            end
            return result
        end
    end
end
