# -*- coding: utf-8 -*-
require_relative './base_method'

module DSN

    #= MergeMethod class
    # To analyze the merge method of DSN description.
    #
    #@author NICT
    #
    class MergeMethod < BaseMethod
        METHOD_NAME = "merge"

        def initialize(delay, srcs)
            @delay = delay
            @srcs  = srcs
        end

        # It determines whether the character string corresponding to the merge method.
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # To analyze the merge method syntax.
        #
        #@param [DSNText] text  String of method
        #@return [Array<String>] Array of arguments of the method
        #@raise [DSNFormatError] Not in the correct format as a method
        #
        def self.parse(text)
            # To include the variable-length argument, first to get the number of arguments without the format specified.
            format = nil
            args = BaseMethod.parse(text, METHOD_NAME, format)
            if args.size < 1
                raise DSNFormatError.new(ErrorMessage::ERR_MERGE_METHOD, text)
            end
            # Set the format corresponding to the length of the argument, and re-parse.
            format = [[TYPE_INTEGER]]
            # To add a variable-length argument.
            (args.size - 1).times do
                format << [TYPE_DATANAME]
            end
            args = BaseMethod.parse(text, METHOD_NAME, format)

            delay = args[0].single_line
            srcs  = args.drop(1).map {|arg| arg.single_line} 

            return MergeMethod.new(delay, srcs)
        end

        # It is converted into an intermediate code.
        def to_hash()
            return {
                KEY_TYPE      => METHOD_NAME,
                KEY_DELAY     => @delay,
                KEY_MERGE_SRC => @srcs
            }
        end
    end
end
