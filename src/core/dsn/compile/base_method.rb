# -*- coding: utf-8 -*-
require_relative './dsn_text'
require_relative './dsn_define'
require_relative './error_message'
require_relative '../../utils'

module DSN

    #= BaseMethod class
    # To analyze the method of DSN description.
    #
    #@author NICT
    #
    class BaseMethod

        # Return the method name and arguments of the methods specified in the argument
        #
        #@param [DSNText] text  Target string
        #@return [Array<DSNText>] Method name, Argument
        #
        def self.match(method_text)
            reg = REG_METHOD_FORMAT.match(method_text.single_line)
            if reg.nil?
                return nil
            end
            return DSNText.new(method_text.text,method_text.line_offset,reg[CAP_INDEX_METHOD_NAME]),
            DSNText.new(method_text.text,method_text.line_offset,reg[CAP_INDEX_METHOD_ARG])
        end

        # It determines whether the method specified in the argument
        #
        #@param [DSNText] text         Target string
        #@param [String]  method_name  Method name
        #@return [Boolean] If the subject of the method returns true
        #
        def self.match?(method_text,method_name)
            method, attr = match(method_text)
            if method.nil?
                return false
            end
            return ( method.single_line == method_name )
        end

        # To analyze the method[format of method name(argument1, argument2)]
        #
        #@param [DSNText]       text         String of method
        #@param [String]        method_name  Method name
        #@param [Array<String>] format       Format of argument of method
        #@return [Array<DSNText>] Array of argument of method
        #@raise [DSNFormatError] Not in the correct format as a method
        #
        def self.parse(dsn_text, method_name, format=nil)

            # To check the overall format of the method.
            check_format(dsn_text,method_name)

            name, argument_line = match(dsn_text)
            arguments = DSNText.split_comma(argument_line)

            # Perform the type conversion of the method argument for split result.
            # If the format is not specified, not carried out.
            unless format.nil?
                arguments = convert_argument_format(arguments, format, method_name)
            end

            return arguments
        end

        # To check the format of the method (Except for the argument portion)
        #
        #@param [DSNText] text         String of method
        #@param [String]  method_name  Method name
        #@raise [DSNFormatError] Not in the correct format as a method
        #
        def self.check_format(text,method_name)
            # The beginning of the string of the method matches the method name.
            # That the next character of the method name is "(".
            # That the last character of the method name is ")".
            if text.single_line =~ /^#{method_name}\(#{REG_METHOD_ARG}\)$/
                # If the match is a normal (not nothing)
            else
                raise DSNFormatError.new(ErrorMessage::ERR_FORMAT_METHOD, text)
            end

        end

        # Convert to determine the type of argument.
        #
        #@param [String] param  Determination target string
        #@return [datatype] String, integer, one of the real number
        #@raise [DSNFormatError] It is not appropriate string
        #@note Exponential notation such as "10e+05" does not support.
        #
        def self.convtype(param)
            if param =~ /^-?\d*$/         # integer
                return param.to_i
            elsif param =~ /^-?\d+\.\d+$/ # real number
                return param.to_f
            elsif param =~ /^\"(.*)\"$/   # string
                return $1.to_s
            else
                # String having a plurality of the decimal point,
                # and string is not enclosed in parentheses, it is an error.
                msg = "#{ErrorMessage::ERR_ARGUMENT_FORMAT}\ninput: #{param}"
                raise DSNInternalFormatError.new(msg)
            end
        end

        # To check the time of the string format
        #
        #@param [String] param  Determination target string
        #@return [String] Time string
        #@raise [DSNFormatError] Inappropriate string as time
        #
        def self.time_format_check(param)
            time = BaseMethod.convtype(param)
            if time.is_a?(String)
                # If it can not be converted to time and error.
                if time_to_sec(time).is_a?(Fixnum)
                    return time
                end
            end
            # If the process has reached here, and all errors.
            msg = "#{ErrorMessage::ERR_TIMEDATA_FORMAT}\ninput: #{param}"
            raise DSNInternalFormatError.new(msg)
        end

        # To check the string format of the data name
        #
        #@param [String] param  Determination target string
        #@return [String] Data name
        #@raise [DSNFormatError] Inappropriate string
        #
        def self.dataname_check(param)
            if param =~ /^\w+$/ # Alphabet, numbers, and "_" only allowed.
                return param.to_s
            else

                msg = "#{ErrorMessage::ERR_DATANAME_FORMAT}\ninput: #{param}"
                raise DSNInternalFormatError.new(msg)
            end
        end

        # To change the format of the method argument(single_line part) that is included in the DSNText after parsing.
        #
        #@param [Array<DSNText>] arguments   Method argument after parse
        #@param [Array]          exp_format  Type that is expected as each argument
        #                                        TYPE_DATANAME: data name
        #                                        TYPE_INTEGER : integer
        #                                        TYPE_FLOAT   : float
        #                                        TYPE_STRING  : string
        #                                        TYPE_TIME    : time
        #                                        TYPE_ANY     : do not check
        #                                        The above, to specify a two-dimensional array
        #   ex. Expected value of the argument is "data name", "integer or float", "string"
        #       arguments = [[TYPE_DATANAME], [TYPE_INTEGER, TYPE_FLOAT],[TYPE_STRING]]
        #@return [Array<DSNText>] That @single_line is converted to the appropriate object type
        #@raise [DSNFormatError] It does not match the type and the type after parse, which is expected
        #
        def self.convert_argument_format(arguments, exp_format, method_name)

            # Number of arguments after the analysis and the number of arguments that are expected to ensure that they match.
            if arguments.length != exp_format.length
                # If they do not match, an error, to display the correct format of the method.
                msg = "#{ErrorMessage::ERR_ARGUMENTS}\n#{ErrorMessage::FORMAT_HASH[method_name]}"
                raise DSNInternalFormatError.new(msg)
            end

            ret = []
            count = 1

            # Argument after the analysis is to see if the expected type.
            # The expected value of the type to get more up, an error only if there is no match to the end.
            arguments.zip(exp_format) do | arg, exp |
                out = nil
                exp.each do | type |
                    begin
                        out = try_convert(arg.single_line, type)
                        break
                    rescue
                    end
                end

                # To create a text if it match the expected value.
                # An error if it does not match.
                if out != nil
                    dsn = DSNText.new(arg.text, arg.line_offset, out)
                else
                    # Or argument of the problem is what was largest in the what,
                    # include whether the type which is expected to what was in the error message.
                    case count
                    when 1
                        ordinal = "1st"
                    when 2
                        ordinal = "2nd"
                    when 3
                        ordinal = "3rd"
                    else
                        ordinal = "#{count}th"
                    end
                    error_msg = "The #{ordinal} argument \"#{arg.single_line}\" does not have the expected data format: #{exp}"
                    msg = "#{ErrorMessage::ERR_DATA_TYPE}\n#{error_msg}"
                    raise DSNInternalFormatError.new(msg)
                end

                # Stores it in the output array.
                ret << dsn
                count += 1
            end
            return ret
        end

        # To convert the type of the input string, to match the expected value.
        #
        #@param [String] param  String of method
        #@param [String] exp    Expected value for the param
        #@return [Integer/Float/String] Param after check
        #@raise [DSNFormatError] Not in the correct format
        #
        def self.try_convert(param, exp)
            case exp
            when TYPE_DATANAME
                out = BaseMethod.dataname_check(param)
            when TYPE_INTEGER
                out =  BaseMethod.convtype(param)
                unless out.is_a?(Integer)
                    raise ArgumentError
                end
            when TYPE_FLOAT
                out =  BaseMethod.convtype(param)
                unless out.is_a?(Float)
                    raise ArgumentError
                end
            when TYPE_STRING
                out =  BaseMethod.convtype(param)
                unless out.is_a?(String)
                    raise ArgumentError
                end
            when TYPE_TIME
                out =  BaseMethod.time_format_check(param)
            when TYPE_ANY
                # No always a problem if any is specified.
                out = param
            else
                # Not an error of the DSN description,
                # if the mold incorrect in the method is designated as an error.
                raise "Specified TYPE is not correct."
            end
            return out
        end

        # Input string to check whether the reserved word
        #
        #@param [String] param  Determination target string
        #@return [Boolian] True: reserved word, False: not reserved word
        #
        def self.reserved?(param)
            ret = RESERVED_ARRAY.any? {|word| word == param}
            return ret
        end
    end
end
