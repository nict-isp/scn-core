# -*- coding: utf-8 -*-
require_relative './dsn_text'
require_relative './state_do'
require_relative './servicelinks'
require_relative './conditions'

module DSN

    #= EventsDoブロッククラス
    # DSN記述のevents doブロックを管理する。
    #@author NICT
    #
    class EventsDo < Syntax

        #@return [ServiceLink] service_link ServiceLinkクラスのインスタンス
        attr_reader :service_link

        #
        def initialize()
            super()
            @name = "event conditions do"
            @end_block = false
        end

        # 構文開始判定処理
        #
        #@param [String] line DSN記述の文字列一行
        #@return [Syntax] DSN記述構文サブクラスのインスタンス
        #@return [nil] 構文開始条件不成立
        #
        def self.start_line?(line)
            log_trace(line)
            outside_string = DSNText.replace_inside_string(line)
            if outside_string =~ REG_BLOCK_DO_FORMAT && outside_string !~ REG_BLOOM_BLOCK_FORMAT
                return EventsDo.new()
            else
                return nil
            end
        end

        # 構文解析処理
        #
        #@param [String] line DSN記述の文字列一行
        #@param [Integer] offset 文字列の先頭行数
        #@return [Boolean] 構文終了
        #
        def parse_line(line, offset)
            log_trace(line, offset)
            super(line, offset)

            if DSNText.replace_inside_string(line) =~ REG_BLOCK_END_FORMAT
                @end_block = true
                return true
            else
                return false
            end
        end

        def is_end?()
            return @end_block
        end

        #構文内部解析処理
        #
        #@param [StateDo] state doブロックのDSN記述
        #@raise [DSNFormatError] 構文として正しくないデータが設定された。
        #
        def parse_inside(state)
            log_debug(){"#{@dsn_text}"}
            @dsn_text.delete(-1)    # end

            #DSN記述の中から,events_condition部分とservicelink部分を取り出す。
            event_text = _parse_event_condition()

            #servicelinks構文(transmission & trigger)の設定をおこなう。
            @service_link = ServiceLinks.new()
            @service_link.parse_inside(@dsn_text, state, @syntax_name)

            @events_condition = Conditions.parse(event_text)

            return self
        rescue DSNInternalFormatError => err
            log_error err.backtrace.join("\n")
            raise DSNFormatError.new(err.message, @dsn_text)
        end

        # event condition抽出
        def _parse_event_condition()
            event_text = @dsn_text.delete(0)
            log_debug(){"#{event_text}"}  # bloom do
            if event_text.slice!(-2,2) != "do"
                # バグ以外ありえない
            end
            return DSNText.new(event_text, @dsn_text.line_offset, event_text)
        end

        # event condition中のevent name収集
        def get_event_names()
            event_names = @events_condition.get_data_names
            return event_names.uniq
        end

        # EventsDo部分を中間コードに変換する。
        #
        #@param なし
        #@return [Hash] events doブロックの中間コード
        #@example
        #
        def to_hash()
            result = @service_link.to_hash
            result = result.merge({KEY_CONDITIONS => @events_condition.to_hash})
            return result
        end

    end

end
