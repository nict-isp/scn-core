# -*- coding: utf-8 -*-
require_relative './base_method'
require_relative './time_method'

module DSN

    #= CullTimeMethod class
    # To analyze the cull_time method of DSN description.
    #
    #@author NICT
    #
    class CullTimeMethod < BaseMethod
        METHOD_NAME = "cull_time"

        POS_DATA_NAME = 0
        POS_TIME = 1

        #@return [String] Numerator
        attr_reader :numerator
        #@return [String] Denominator
        attr_reader :denominator
        #@return [TimeMethod] Instance of time method
        attr_reader :time_instance

        #
        def initialize(numerator, denominator, time )
            @numerator     = numerator
            @denominator   = denominator
            @time_instance = time
        end

        # It determines whether the character string corresponding to the cull_time method.
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # To analyze the cull_time method syntax.
        #
        #@param [DSNText] text  String of method
        #@return [Array<String>] Array of arguments of the method
        #@raise [DSNFormatError] Not in the correct format as a method
        #
        def self.parse(text)
            format = [[TYPE_INTEGER],[TYPE_INTEGER],[TYPE_ANY]]
            args   = BaseMethod.parse(text, METHOD_NAME, format)

            # Take out the numerator and denominator.
            numerator   = args[0].single_line
            denominator = args[1].single_line
            time        = TimeMethod.parse(args[2])

            # If the numerator and denominator is less than or equal to zero, an error.
            # If the numerator is smaller than the denominator, and error.
            diff = denominator - numerator
            unless numerator > 0 && denominator > 0 && diff >= 0
                msg = "numerator: #{numerator}, denominator: #{denominator}"
                raise DSNFormatError.new(ErrorMessage::ERR_CULL_VALUE, text, msg)
            end

            return CullTimeMethod.new(numerator, denominator, time)
        end

        # It is converted into an intermediate code.
        def to_hash()
            time = @time_instance.to_hash
            return { KEY_CULL_TIME => {
                KEY_CULL_NUMERATOR => @numerator,
                KEY_CULL_DENOMINATOR => @denominator,
                KEY_TIME => time[KEY_TIME]
                }}
        end
    end
end
