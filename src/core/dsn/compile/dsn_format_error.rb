# -*- coding: utf-8 -*-

module DSN

    #= DSN description format error class
    # Generated at the time of format error of DSN description.
    #
    #@author NICT
    #
    class DSNFormatError < StandardError

        # It makes display of error messages, log output, and exception output.
        #
        #@param [String]  msg       Error message
        #@param [DSNText] dsn_text  DSN text at the time of the error
        #@param [String]  text      Text of the additional information
        #
        def initialize(msg, dsn_text, text="")
            if dsn_text.class == DSNText
                error_message = "[#{dsn_text.line_offset}]: #{dsn_text.text}: #{msg}: #{text}"
            else
                raise DSNInternalFormatError, "Invalid argument of DSNFormatError."
            end
            super(error_message)

            # To record the error message in the log.
            log_error(error_message)
        end
    end

    class DSNInternalFormatError < StandardError; end
end
