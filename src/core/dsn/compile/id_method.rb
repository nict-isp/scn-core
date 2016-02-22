# -*- coding: utf-8 -*-
require_relative './base_method'

module DSN

    #= IDMethod class
    # To analyze the id method of DSN description.
    #
    #@author NICT
    #
    class IDMethod < BaseMethod
        METHOD_NAME = "id"

        HASH_EMPTY = ""

        #@return [Array]  Intermediate code output when empty
        attr_reader :hash_empty

        #@param [String] id  Identifier of channel
        #
        def initialize(id)
            @id         = id
            @hash_empty = HASH_EMPTY
        end

        # It determines whether the character string corresponding to the id method.
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # To analyze the id method syntax
        #
        #@param [DSNText] text  String of method
        #@return [Array<String>] Array of arguments of the method
        #
        def self.parse(text)
            format = [[TYPE_ANY]]
            args   = BaseMethod.parse(text, METHOD_NAME, format)

            id = args[0].single_line

            return IDMethod.new(id)
        end

        # It is converted into an intermediate code.
        def to_hash()

            result = @id.nil?() ? @hash_empty : @id
            return result
        end
    end
end
