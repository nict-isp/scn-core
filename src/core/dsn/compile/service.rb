# -*- coding: utf-8 -*-
require_relative './discovery'
require_relative './dsn_text'
require_relative './dsn_define.rb'

module DSN

    #= Service class
    # To convert the "discovery" syntax of DSN described in the intermediate code.
    #
    #@author NICT
    #
    class Service < Syntax

        #@return [String] service name
        attr_reader :name
        #@return [Hash<String,Array<String>>] key:attr_name, value:[attr_value1,…]
        attr_reader :attr_data

        def initialize()
            super()
            @syntax_name = "service"
            @continued_line = "" # Continuation of the previous line
        end

        # Syntax start determination processing
        #
        #@param [String] line  String line of DSN description
        #@return [Syntax] Instance of a DSN description syntax subclass
        #@return [nil]    Syntax start condition is not established
        #
        def self.start_line?(line)
            log_trace(line)
            if DSNText.replace_inside_string(line) =~ REG_SERVICE_START_FORMAT
                return Service.new()
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
            log_trace(line, offset)

            left_line = @continued_line
            left_line << line

            if @name.nil?
                left_line = _parse_name(left_line)
            end
            if @attr_data.nil?
                left_line = _parse_attr_data(left_line)
            end

            if @name && @attr_data
                if left_line.size == 0
                    return true
                else
                    @continued_line = left_line
                    return false
                end
            else
                @continued_line = left_line
                return false
            end
        end

        # Service name analysis processing
        #
        #@param [String] line  String line of DSN description
        #@return [String] Unanalyzed string
        #
        def _parse_name(line)
            log_trace(line)
            @name, left_line = DSNText.split(line, ":", 2, false)
            # For call after match in start_line, the validity of "@ name" is unnecessary.
            if left_line.nil?
                left_line = ""
            end
            return left_line
        end

        # Information extraction analysis process
        #
        #@param [String] line String line of DSN description
        #@return [String] Unanalyzed string
        #
        def _parse_attr_data(line)
            log_trace(line)
            line.strip!
            return line if line.size == 0 # It is determined that continued on the next line.

            if DiscoveryMethod.is_method?(line)
                if line[-1] == ")"
                    method_text = DSNText.new(@dsn_text.text, @dsn_text.line_offset, line)
                    @attr_data = DiscoveryMethod.parse(method_text)
                    return ""
                else
                    return line # It is determined that continued on the next line.
                end
            else
                raise DSNInternalFormatError, ErrorMessage::ERR_DISCOVERY_FORMAT
            end
        end

        # Syntax internal analysis process
        def parse_inside()
            # The service name check is not necessary because it done at the time of taking out the syntax.
            # Confirmation of the reserved word even without the need.

            return self
        rescue DSNInternalFormatError => err
            log_error err.backtrace.join("\n")
            raise DSNFormatError.new(err.message, @dsn_text)
        end

        # To convert the discovery syntax into an intermediate code.
        #
        #@param なし
        #@return [Hash<String,Hash>] Intermediate code of discovery syntax
        #@example
        #   {"@service_name1":{"attr_name1":"attr_value1", "attr_name2":"attr_value2"}}
        #
        #
        def to_hash()
            return {@name => @attr_data}
        end

    end
end
