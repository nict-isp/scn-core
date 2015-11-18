# -*- coding: utf-8 -*-

module DSN

    #= DSN記述フォーマットエラークラス
    # DSN記述のフォーマットエラー時に発生する。
    #
    #@author NICT
    #
    class DSNFormatError < StandardError

        # エラーメッセージの表示、ログ出力、例外出力をおこなう。
        #
        #@param [String] msg エラーメッセージ
        #@param [DSNText] dsn_text エラー発生時のDSNテキスト
        #@param [String] text 追加情報のテキスト
        #
        def initialize(msg, dsn_text, text="")
            if dsn_text.class == DSNText
                error_message = "[#{dsn_text.line_offset}]: #{dsn_text.text}: #{msg}: #{text}"
            else
                raise DSNInternalFormatError, "Invalid argument of DSNFormatError."
            end
            super(error_message)

            #エラーメッセージをログに記録する。
            log_error(error_message)
        end
    end

    class DSNInternalFormatError < StandardError; end
end
