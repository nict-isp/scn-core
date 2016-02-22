# -*- coding: utf-8 -*-
require_relative './base_method'

module DSN

    #= VirtualMethod class
    # To analyze the virtual method of DSN description.
    #
    #@author NICT
    #
    class VirtualMethod < BaseMethod
        METHOD_NAME = "virtual"

        def initialize(virtual, expr)
            @virtual = virtual
            @expr    = expr
        end

        # It determines whether the character string corresponding to the virtual method.
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # To analyze the virtual method syntax.
        #
        #@param [DSNText] text  String of method
        #@return [Array<String>] Array of arguments of the method
        #@raise [DSNFormatError] Not in the correct format as a method
        #
        def self.parse(text)
            format  = [[TYPE_DATANAME], [TYPE_STRING]]
            args    = BaseMethod.parse(text, METHOD_NAME, format)
            virtual = args[0].single_line 
            expr    = args[1].single_line

            return VirtualMethod.new(virtual, expr)
        end

        def to_hash()
            return {
                KEY_VIRTUAL => {
                    KEY_VIRTUAL_NAME => @virtual,
                    KEY_VIRTUAL_EXPR => @expr,
                }
            }
        end
    end
end
