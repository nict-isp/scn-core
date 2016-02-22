#-*- coding: utf-8 -*-
require_relative './condition'

module DSN

    #= A range method to intermediate encoding. In addition, 
    # the condition for determining based on the intermediate code.
    #
    #@author NICT
    #
    class RangeMethodCondition < Condition
        METHOD_NAME = "range"

        # Determines whether or not the target string of RangeMethodCondtion.
        #
        #@param [DSNText] expression  Inspected string
        #@return [Boolean] True if target, false otherwise
        #
        def self.match?(expression)
            return BaseMethod::match?(expression,METHOD_NAME)
        end

        # To create an instance from a string.
        #
        #@param [DSNText] expression  String to be converted
        #@return [RangeMethodCondtion] Instance of RangeMethodCondition
        #@raise [DSNFormatError] Inappropriate as an input method
        #
        def self.parse(expression)
            format = [[TYPE_DATANAME], [TYPE_INTEGER, TYPE_FLOAT, TYPE_TIME, TYPE_STRING], [TYPE_INTEGER, TYPE_FLOAT, TYPE_TIME, TYPE_STRING]]

            args_data = BaseMethod.parse(expression, METHOD_NAME, format)

            data_name = args_data.shift
            data_name_string = data_name.single_line
            args_data_array = args_data.map{|arg| arg.single_line}

            min = args_data_array[0]
            max = args_data_array[1]

            # If the type of the min and max is different it is determined that the error.
            # However, integer and real number difference is allowed.
            # In the case of integer once converted into a real number.
            temp_min = min
            temp_max = max
            if min.is_a?(Integer)
                min = min.to_f
            end
            if max.is_a?(Integer)
                max = max.to_f
            end

            # The combination of strings and function determines that error.
            unless min.kind_of?(max.class)
                min = temp_min
                max = temp_max
                msg = "min: #{min.class}, max: #{max.class}"
                raise DSNFormatError.new(ErrorMessage::ERR_RANGE_TYPE, expression, msg)
            end

            # If min is greater than max, determines that the error.
            if min > max
                min = temp_min
                max = temp_max
                msg = "min: #{min}, max: #{max}"
                raise DSNFormatError.new(ErrorMessage::ERR_RANGE_BACK, expression, msg)

            end

            return RangeMethodCondition.new(data_name_string,METHOD_NAME, args_data_array)
        end

        #指定された中間コードのデータが条件を満たしているか判定する。
        #
        #@param [String]        key     Data name of the target is determined conditions
        #@param [Array<String>] values  Judgment condition, threshold
        #@param [Hash<String>]  data    Hash with a data name of the condition determination target key,
        #                               and with the value of the condition determination target value.
        #@return [Boolean] If it meet the condition true, not meet the condition false
        #                  If the type of determination target and the data are different, false
        #
        def self.ok?(key, values, data)
            sign, min, max = values
            variable = data[key]

            # For carrying out a comparison of integer and real numbers, to convert an integer to a real number.
            if min.is_a?(Integer)
                min = min.to_f
            end
            if max.is_a?(Integer)
                max = max.to_f
            end
            if variable.is_a?(Integer)
                variable = variable.to_f
            end

            if variable.kind_of?(min.class)
                case sign
                when METHOD_NAME
                    if min <= variable && variable < max
                        result = true
                    else
                        result = false
                    end
                else
                    raise ArgumentError, "invalid method(=#{sign})"
                end
            else
                result = false
            end
        end
    end
end
