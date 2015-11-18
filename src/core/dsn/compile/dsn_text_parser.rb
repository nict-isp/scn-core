# -*- coding: utf-8 -*-
require_relative './dsn_define'
require_relative './dsn_text'
require_relative './dsn_format_error'

module DSN

    #= DSN記述構文読み取りクラス
    # DSN記述の構文を取り扱う。
    #
    #@author NICT
    #
    class DSNTextParser

        #@param [Array<Class>] DSN記述構文クラスの配列
        #
        def initialize( syntaxs_class )
            @syntaxs_class = syntaxs_class
        end

        #@param [DSNText] DSN記述
        #@return [Array<Syntax>] DSN記述構文インスタンスの配列
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
                        # 有効なDSN記述ブロック/構文と一致しません
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
                # 構文の終端が存在しません。
                raise DSNFormatError.new(
                ErrorMessage::ERR_NO_TERMINATOR,
                syntax.dsn_text, syntax.syntax_name)
            end

            return syntax_elements
        end

    end
end
