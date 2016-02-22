# -*- coding: utf-8 -*-
require_relative './base_method'

module DSN

    #= QoSMethod class
    # To analyze the QoS method of DSN description.
    #
    #@author NICT
    #
    class QoSMethod < BaseMethod
        METHOD_NAME = "qos"

        HASH_EMPTY = {}

        #@return [Array] intermediate code output when empty
        attr_reader :hash_empty

        # Default priority
        # If the priority can be specified it is considered that the user likes arbitrarily set a numeric value.
        # Because it can not guarantee the priority completely, it is on the DSN description keep set up so that they can not be.
        PRIORITY_DEFAULT = 100

        #@param [Integer] bandwidth  Bandwidth
        #@param [Integer] priority   Communication priority
        #
        def initialize(bandwidth, priority)
            @bandwidth  = bandwidth
            @priority   = priority
            @hash_empty = HASH_EMPTY
        end

        # It determines whether the character string corresponding to the qos method.
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # To analyze the qos method syntax.
        #
        #@param [DSNText] text  String of method
        #@return [Array<String>] Array of arguments of the method
        #
        def self.parse(text)
            format = [[TYPE_INTEGER]]
            args   = BaseMethod.parse(text, METHOD_NAME, format)

            bandwidth = args[0].single_line
            priority  = PRIORITY_DEFAULT

            return QoSMethod.new(bandwidth, priority)
        end

        # It is converted into an intermediate code.
        def to_hash()

            if @bandwidth.nil?() && @priority.nil?()
                result = @hash_empty
            else
                result = {
                    KEY_QOS_BANDWIDTH => @bandwidth,
                    KEY_QOS_PRIORITY  => @priority
                }
            end
            return result
        end
    end
end
