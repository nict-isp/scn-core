# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative './base_method'

module DSN

    #= AggregateMethod class
    # To analyze the aggregate method of DSN description.
    #
    #@author NICT
    #
    class AggregateMethod < BaseMethod
        METHOD_NAME = "aggregate"

        def initialize(data, timeout, delay, space)
            @data_name      = data
            @timeout        = timeout
            @delay          = delay
            @space_instance = space
        end

        # It determines whether the character string corresponding to the aggregate method.
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # To analyze the aggregate method syntax.
        #
        #@param [DSNText] text  String of method
        #@return [Array<String>] Array of arguments of the method
        #@raise [DSNFormatError] Not in the correct format as a method
        #
        def self.parse(text)
            # The fourth argument is for the optional, first, to get the number of arguments.
            format = nil
            args = BaseMethod.parse(text, METHOD_NAME, format)

            # It defines the format depending on the number of arguments, and re-analysis.
            if args.size() == 4
                format = [[TYPE_DATANAME],[TYPE_INTEGER],[TYPE_INTEGER],[TYPE_ANY]]
            else
                format = [[TYPE_DATANAME],[TYPE_INTEGER],[TYPE_INTEGER]]
            end
            args = BaseMethod.parse(text, METHOD_NAME, format)

            dataname = args[0].single_line
            timeout  = args[1].single_line
            delay    = args[2].single_line
            space    = args.size() == 4 ? SpaceMethod.parse(args[3]) : nil

            return AggregateMethod.new(dataname, timeout, delay, space)
        end

        # It is converted into an intermediate code.
        def to_hash()
            space = @space_instance.nil?() ? nil : @space_instance.to_hash[KEY_SPACE]
            return {
                KEY_AGGREGATE => {
                    KEY_AGGREGATE_DATA_NAME => @data_name,
                    KEY_TIMEOUT             => @timeout,
                    KEY_DELAY               => @delay,
                    KEY_SPACE               => space
                }}
        end

    end

end
