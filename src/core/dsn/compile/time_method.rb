# -*- coding: utf-8 -*-
require_relative './base_method'

module DSN

    #= TimeMethod class
    # To analyze the DSN description time method.
    #
    #@author NICT
    #
    class TimeMethod < BaseMethod
        METHOD_NAME = "time"

        # Order of the arguments of the method
        POS_DATA_NAME = 0
        POS_START_TIME = 1
        POS_END_TIME = 2
        POS_TIME_INTERVAL = 3
        POS_TIME_UNIT = 4

        def initialize( args_data )
            @data_name = args_data[POS_DATA_NAME]
            @start_time = args_data[POS_START_TIME]
            @end_time = args_data[POS_END_TIME]
            @interval = args_data[POS_TIME_INTERVAL]
            @unit = args_data[POS_TIME_UNIT]
        end

        # It determines whether the character string corresponding to the time method.
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # To analyze the time method syntax.
        #
        #@param [DSNText] text  String of method
        #@return [Array<Integer|Float|String>] Array of arguments of the method
        #@raise [DSNFormatError] Not in the correct format as a method
        #
        def self.parse(text)
            format = [[TYPE_DATANAME],[TYPE_TIME],[TYPE_TIME],[TYPE_INTEGER],[TYPE_STRING]]

            args = BaseMethod.parse(text, METHOD_NAME, format)

            # In the case of unit of time day, hour, minute, otherwise second and error.
            units = ["day", "hour", "minute", "second"]
            unless units.any?{|unit| unit == args[4].single_line}
                msg = "input: #{args[4].single_line}"
                raise DSNFormatError.new(ErrorMessage::ERR_TIME_UNIT, args[4], msg)
            end

            # In the case of starttime> endtime and error.
            starttime = time_to_sec(args[1].single_line)
            endtime   = time_to_sec(args[2].single_line)
            if starttime > endtime
                msg = "starttime: #{args[1].single_line}, endtime: #{args[2].single_line}"
                raise DSNFormatError.new(ErrorMessage::ERR_TIME_BACK, text, msg)
            end

            # In the case of interval <= 0 and error.
            if args[3].single_line <= 0
                msg = "interval: #{args[3].single_line}"
                raise DSNFormatError.new(ErrorMessage::ERR_TIME_INTERVAL, text, msg)
            end

            return TimeMethod.new(args.map{|arg| arg.single_line})
        end

        # It is converted into an intermediate code.
        def to_hash()
            return {KEY_TIME =>{
                KEY_TIME_DATA_NAME => @data_name,
                KEY_START_TIME => @start_time,
                KEY_END_TIME => @end_time,
                KEY_TIME_INTERVAL => @interval,
                KEY_TIME_UNIT => @unit
                }}
        end
    end
end
