# -*- coding: utf-8 -*-
require_relative './base_method'
require_relative './space_method'

module DSN

    #= CullSpaceMethod class
    # To analyze the cull_space method of DSN description.
    #
    #@author NICT
    #
    class CullSpaceMethod < BaseMethod
        METHOD_NAME = "cull_space"

        #@return [String] Numerator
        attr_reader :numerator
        #@return [String] Denominator
        attr_reader :denominator
        #@return [SpaceMethod] Instance of time method
        attr_reader :space_instance

        #
        def initialize(numerator, denominator, space)
            @numerator      = numerator
            @denominator    = denominator
            @space_instance = space
        end

        # It determines whether the character string corresponding to the cull_space method.
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # To analyze the cull_face method syntax.
        #
        #@param [String] text  String of method
        #@return [Array<String>] Array of arguments of the method
        #@raise [ArgumentError] Not in the correct format as a method
        #
        def self.parse(text)
            format = [[TYPE_INTEGER],[TYPE_INTEGER],[TYPE_ANY]]
            args   = BaseMethod.parse(text, METHOD_NAME, format)

            # Take out the numerator and denominator.
            numerator   = args[0].single_line
            denominator = args[1].single_line
            space       = SpaceMethod.parse(args[2])

            # If the numerator and denominator is less than or equal to zero, an error.
            # If the numerator is smaller than the denominator, and error.
            diff = denominator - numerator
            unless numerator > 0 && denominator > 0 && diff >= 0
                msg = "numerator: #{numerator}, denominator: #{denominator}"
                raise DSNFormatError.new(ErrorMessage::ERR_CULL_VALUE, text, msg)
            end

            return CullSpaceMethod.new(numerator, denominator, space)
        end

        # It is converted into an intermediate code.
        def to_hash()
            space = @space_instance.to_hash
            return { KEY_CULL_SPACE => {
                KEY_CULL_NUMERATOR => @numerator,
                KEY_CULL_DENOMINATOR => @denominator,
                KEY_SPACE => space[KEY_SPACE]
                }}
        end
    end
end
