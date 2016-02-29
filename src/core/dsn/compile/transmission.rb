# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative './discovery'
require_relative './dsn_text'
require_relative './dsn_define'
require_relative './filter_method'
require_relative './cull_time_method'
require_relative './cull_space_method'
require_relative './aggregate_method'
require_relative './virtual_method'
require_relative './select_method'
require_relative './meta_method'
require_relative './qos_method'
require_relative './id_method'
require_relative './string_method'

module DSN

    #= Data transfer class
    # To convert the transmission syntax of DSN described in the intermediate code.
    #
    #@author NICT
    #
    class Transmission < Syntax

        # The key of hash that returns a result of analysis of the right-hand side value
        SCRATCH_DATA = "scratch"
        PROCESSING_DATA = "processing"

        #@return [Communication] Instance of the corresponding channel
        attr_reader :channel
        #@return [Communication] Instance of the corresponding scratch
        attr_reader :scratch
        #@return [Integer] Number of lines in the DSN description
        attr_reader :line_offset
        #@return [Array<Processing>] Instance that corresponds to the method to be executed
        attr_reader :processings
        #@return [SelectMethod] Instance that corresponds to the select method
        attr_reader :select
        #@return [QoSMethod] Instance that corresponds to the QoS method
        attr_reader :qos
        #@return [MetaMethod] Instance that corresponds to the meta method
        attr_reader :meta
        #@return [IDMethod] Instance that corresponds to the id method
        attr_reader :id

        #@param [Communication] channel     Instance of the corresponding channel
        #@param [Communication] scratch     Instance of the corresponding scratch
        #@param [Processing]    processing  Instance that corresponds to the method to be executed
        #
        def initialize()
            super()
            @syntax_name    = "transmission"
            @continued_line = "" # continuation of the previous line

            @processings    = []
            @select         = SelectMethod.new(nil)
            @meta           = MetaMethod.new(nil)
            @qos            = QoSMethod.new(nil, nil)
            @id             = IDMethod.new(nil)
        end

        # Syntax start determination processing
        #
        #@param [String] line  String line of DSN description
        #@return [Syntax] Instance of a subclass of DSN description syntax
        #@return [nil]    Syntax start condition is not satisfied
        #
        def self.start_line?(line)
            log_trace(line)
            if DSNText.replace_inside_string(line) =~ REG_TRANSMISSION_START_FORMAT
                return Transmission.new()
            else
                return nil
            end
        end

        # Parsing process
        #
        #@param [String]  line    String line of DSN description
        #@param [Integer] offset  The number of the first line of the string
        #@return [Boolean] Syntax Exit
        #
        def parse_line(line, offset)
            super(line, offset)

            @line_offset = offset

            left_line = @continued_line
            left_line << line

            if @channel_name.nil?
                left_line = _parse_channel(left_line)
            end

            if @scratch_name.nil? && @processing_line.nil?
                left_line = _parse_scratch(left_line)
                if left_line.size == 0
                    return true
                else
                    @continued_line = left_line
                    return false
                end
            end
        end

        # Channel name analysis processing
        #
        #@param [String] line  String line of DSN description
        #@return [String] Unanalyzed string
        #
        def _parse_channel(line)
            @channel_name, left_line = DSNText.split(line, "<~", 2, false)
            # For call after match in start_line, validity of channel_name check unnecessary.
            if left_line.nil?
                left_line = ""
            end
            return left_line
        end

        # Scratch name analysis processing
        #
        #@param [String] line  String line of DSN description
        #@return [String] Unanalyzed string
        #
        def _parse_scratch(line)
            log_trace(line)

            left_line = ""
            if line.include?("(")
                if DSNText.close_small_brackets?(line)
                    @processing_line = line
                    left_line = ""
                else
                    left_line = line
                end
            else
                @scratch_name = line.strip
                @processing_line = nil
            end
            return left_line
        end

        # Syntax internal analysis process
        #
        #@param [StateDo] state  Instance that manages the state do block of DSN description
        #@example
        #  channel_name <~ scratch_name
        #  channel_name <~ scratch_name.filter(condtions)
        #@return [Transmission] Instance of Transmission class
        #@raise [DSNFormatError] Incorrect data as transmission syntax has been set
        #
        def parse_inside(state)

            @channel = state.get_channel(@channel_name)
            if @channel.nil?
                raise DSNFormatError.new(ErrorMessage::ERR_CHANNEL_UNDEFINED, @dsn_text, @channel_name)
            end

            if @processing_line.nil?
                @scratch     = state.get_scratch(@scratch_name)
            else
                reg = REG_PROCESSING_FORMAT.match(@processing_line)
                if not reg.nil?()
                    dsn_processings = DSNText.split(reg["processing"], ".")

                    dsn_processings.each do |processing|
                        method = self._parse_method(processing)
                        @processings << method["processing"]  if method.has_key?("processing")
                        @select      =  method["select"]      if method.has_key?("select")
                        @meta        =  method["meta"]        if method.has_key?("meta")
                        @qos         =  method["qos"]         if method.has_key?("qos")
                        @id          =  method["id"]          if method.has_key?("id")
                    end

                    @scratch_name = reg["scratch_name"]
                    @scratch      = state.get_scratch(@scratch_name)
                else
                    raise DSNFormatError.new(ErrorMessage::ERR_TRANSMISSION_METHOD, @processing_line)
                end
            end

            if @scratch.nil?
                raise DSNFormatError.new(ErrorMessage::ERR_SCRATCH_UNDEFINED, @dsn_text, @scratch_name)
            end

            return self
        rescue DSNInternalFormatError => err
            log_error err.backtrace.join("\n")
            raise DSNFormatError.new(err.message, @dsn_text)
        end

        # Intermediate treatment parsing process
        def _parse_method(processing)
            method    = Hash.new()
            proc_text = DSNText.new(@dsn_text.text, @dsn_text.line_offset, processing)

            case
            when FilterMethod.match?(proc_text)
                method["processing"] = FilterMethod.parse(proc_text)
            when CullTimeMethod.match?(proc_text)
                method["processing"] = CullTimeMethod.parse(proc_text)
            when CullSpaceMethod.match?(proc_text)
                method["processing"] = CullSpaceMethod.parse(proc_text)
            when AggregateMethod.match?(proc_text)
                method["processing"] = AggregateMethod.parse(proc_text)
            when StringMethod.match?(proc_text)
                method["processing"] = StringMethod.parse(proc_text)
            when VirtualMethod.match?(proc_text)
                method["processing"] = VirtualMethod.parse(proc_text)
            when SelectMethod.match?(proc_text)
                method["select"]     = SelectMethod.parse(proc_text)
            when MetaMethod.match?(proc_text)
                method["meta"]       = MetaMethod.parse(proc_text)
            when QoSMethod.match?(proc_text)
                method["qos"]        = QoSMethod.parse(proc_text)
            when IDMethod.match?(proc_text)
                method["id"]         = IDMethod.parse(proc_text)
            else
                # The case of a method that can not be taken as a transmission syntax.
                if /^(\w+)\(.*\)$/ =~ @processing_line
                    msg = "method: #{$1}"
                else
                    msg = ""
                end
                raise DSNFormatError.new(ErrorMessage::ERR_TRANSMISSION_METHOD, proc_text, msg)
            end
            return method
        end

        # Channel identification name
        #
        #@return [String] Name to specify the channel
        #
        def servicelink()
            return "#{@line_offset}:#{@channel_name}<~#{@scratch_name}"
        end

        # It is converted into an intermediate code.
        #
        #@return [Hash<String,String>] Intermediate code(src,dst)
        #
        def to_hash()
            return { KEY_TRANS_SRC => @scratch.service_name,
                KEY_TRANS_DST => @channel.service_name }
        end

    end
end
