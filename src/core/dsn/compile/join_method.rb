# -*- coding: utf-8 -*-
require_relative './base_method'

module DSN

    #= JoinMethod class
    # To analyze the join method of DSN description.
    #
    #@author NICT
    #
    class JoinMethod < BaseMethod
        METHOD_NAME = "join"

        def initialize(delay, virtual, expr, srcs)
            @delay   = delay
            @srcs    = srcs
            @virtual = virtual
            @expr    = expr
        end

        # It determines whether the character string corresponding to the join method.
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # To analyze the join method syntax.
        #
        #@param [DSNText] text  String of method
        #@return [Array<String>] Array of arguments of the method
        #@raise [DSNFormatError] Not in the correct format as a method
        #
        def self.parse(text)
            # To include the variable-length argument, first to get the number of arguments without the format specified.
            format = nil
            args = BaseMethod.parse(text, METHOD_NAME, format)
            if args.size < 3
                raise DSNFormatError.new(ErrorMessage::ERR_JOIN_METHOD, text)
            end
            # Set the format corresponding to the length of the argument, and re-parse.
            format = [[TYPE_INTEGER], [TYPE_DATANAME], [TYPE_STRING]]
            # To add a variable-length argument.
            (args.size - 3).times do
                format << [TYPE_DATANAME]
            end
            args = BaseMethod.parse(text, METHOD_NAME, format)

            delay   = args[0].single_line
            virtual = args[1].single_line
            expr    = args[2].single_line
            srcs    = args.drop(3).map {|arg| arg.single_line} 

            return JoinMethod.new(delay, virtual, expr, srcs)
        end

        # It is converted into an intermediate code.
        def to_hash()
            return {
                KEY_TYPE         => METHOD_NAME,
                KEY_DELAY        => @delay,
                KEY_MERGE_SRC    => @srcs,
                KEY_VIRTUAL_NAME => @virtual,
                KEY_VIRTUAL_EXPR => @expr,
            }
        end
    end
end
