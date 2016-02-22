# -*- coding: utf-8 -*-
require_relative './base_method'

module DSN

    #= StringMethod class
    # To analyze the DSN description string method.
    #
    #@author NICT
    #
    class StringMethod < BaseMethod
        METHOD_NAME = "string"

        def initialize(data_name, operator, param)
            @data_name = data_name
            @operator  = operator
            @param     = param
        end

        # It determines whether the character string corresponding to the string method.
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # To analyze the string method syntax.
        #
        #@param [DSNText] text  String of method
        #@return [Array<String>] Array of arguments of the method
        #@raise [DSNFormatError] Not in the correct format as a method
        #
        def self.parse(text)
            format = nil
            args = BaseMethod.parse(text, METHOD_NAME, format)

            if args.size() < 2
                raise DSNFormatError.new(ErrorMessage::ERR_STRING_FORMAT, text)
            end

            param = []
            data_name = args[0].single_line
            operator  = args[1].single_line

            # Argument is different for each operation.
            case operator
            when "removeBlanks", "lowerCase", "upperCase", "alphaReduce", "numReduce"
                if args.size() != 2
                    raise DSNFormatError.new(ErrorMessage::ERR_STRING_FORMAT0, text)
                end

            when "removeSpecialChars", "concat"
                if args.size() != 3
                    raise DSNFormatError.new(ErrorMessage::ERR_STRING_FORMAT1, text)
                end
                # To delete a forcibly applied to the front and back of the character string "" (double quotes) ".
                param << args[2].single_line.slice(/[^"].*/).slice(/.*[^"]/)

            when "replace", "regexReplace"
                if args.size() != 4
                    raise DSNFormatError.new(ErrorMessage::ERR_STRING_FORMAT2, text)
                end
                param << args[2].single_line.slice(/[^"].*/).slice(/.*[^"]/)
                param << args[3].single_line.slice(/[^"].*/).slice(/.*[^"]/)
            else
                raise DSNFormatError.new(ErrorMessage::ERR_STRING_FORMAT, text)
            end

            return StringMethod.new(data_name, operator, param)
        end

        # It is converted into an intermediate code.
        def to_hash()
            return {
                KEY_STRING => {
                    KEY_STRING_DATA_NAME => @data_name,
                    KEY_OPERATOR         => @operator,
                    KEY_PARAM            => @param
                }}
        end
    end
end
