# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative './dsn_define'
require_relative './dsn_text'
require_relative './dsn_format_error'

module DSN

    #= DSN description syntax reading class
    # It deals with the syntax of the DSN description.
    #
    #@author NICT
    #
    class DSNTextParser

        #@param [Array<Class>] syntaxs_class  Array of DSN description syntax class
        #
        def initialize( syntaxs_class )
            @syntaxs_class = syntaxs_class
        end

        #@param [DSNText] dsn_text  DSN description
        #@return [Array<Syntax>] Array of DSN description syntax instance
        #
        def parse_lines(dsn_text)
            log_trace(dsn_text)
            log_debug(){"#{dsn_text.text}"}
            syntax_elements = []
            syntax = nil
            offset = dsn_text.line_offset
            dsn_text.text.each_with_index do |line, index|
                begin
                    log_debug(){"#{line}"}
                    next if line.size == 0 # blank line
                    if syntax.nil?
                        log_debug(){"#{line}"}
                        @syntaxs_class.each do |clazz|
                            log_debug(){"#{clazz}"}
                            syntax = clazz.start_line?(line)
                            if not syntax.nil?
                                log_trace()
                                break
                            end
                        end
                    end

                    if syntax.nil?
                        # It does not match a valid DNS description block / syntax.
                        raise DSNInternalFormatError, ErrorMessage::ERR_NOT_MATCH_SYNTAX
                    end

                    if syntax.parse_line(line, index + offset)
                        syntax_elements << syntax
                        syntax = nil
                    end
                rescue DSNInternalFormatError => err
                    log_error err.backtrace.join("\n")
                    raise DSNFormatError.new(
                    err.message,
                    DSNText.new(line, index + offset))
                end
            end
            if not syntax.nil?
                # The end of the syntax does not exist.
                raise DSNFormatError.new(
                ErrorMessage::ERR_NO_TERMINATOR,
                syntax.dsn_text, syntax.syntax_name)
            end

            return syntax_elements
        end

    end
end
