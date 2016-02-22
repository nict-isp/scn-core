# -*- coding: utf-8 -*-
require_relative './base_method'
require_relative './conditions'

module DSN

    #= MetaMethod class
    # To analyze the meta method of DSN description.
    #
    #@author NICT
    #
    class MetaMethod < BaseMethod
        METHOD_NAME = "meta"

        HASH_EMPTY = {}

        #@return [Hash] Intermediate code output when empty
        attr_reader :hash_empty

        #@param [Hash] metas  Hash of the meta-information
        #
        def initialize(metas)
            @metas = metas
            @hash_empty = HASH_EMPTY
        end

        # It determines whether the character string corresponding to the meta method.
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # To analyze the meta method syntax.
        #
        #@param [DSNText] text  String of method
        #@return [Array<String>] Array of arguments of the method
        #@raise [DSNFormatError] Not in the correct format as a method
        #
        def self.parse(text)
            format = nil
            args = BaseMethod.parse(text, METHOD_NAME, format)

            metas = Hash.new()
            args.each do |arg|
                reg = REG_META_ARG.match(arg.single_line)
                if not reg.nil?()
                    metas[reg[1]] = reg[2]
                else
                    raise DSNFormatError.new(ErrorMessage::ERR_TRANSMISSION_METHOD, text)
                end
            end

            return MetaMethod.new(metas)
        end

        # It is converted into an intermediate code.
        def to_hash()

            result = @metas.nil?() ? @hash_empty : @metas
            return result
        end
    end
end
