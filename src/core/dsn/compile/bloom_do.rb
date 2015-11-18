# -*- coding: utf-8 -*-
require_relative './dsn_text'
require_relative './state_do'
require_relative './servicelinks'
require_relative './dsn_define'
require_relative './events_do'

module DSN

    #= BloomDoブロッククラス
    # DSN記述のbloom doブロックを管理する。
    #@author NICT
    #
    class BloomDo < Syntax

        attr_reader :syntax_name
        attr_reader :event_do_blocks

        def initialize()
            super()
            @name = "bloom do"

            @event_do_blocks = []
        end

        # 構文開始判定処理
        #
        #@param [String] line DSN記述の文字列一行
        #@return [Syntax] DSN記述構文サブクラスのインスタンス
        #@return [nil] 構文開始条件不成立
        #
        def self.start_line?(line)
            log_trace(line)
            if DSNText.replace_inside_string(line) =~ REG_BLOOM_BLOCK_FORMAT
                return BloomDo.new()
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
            eventdo_end = _parse_for_eventdo(line, offset)

            if eventdo_end
                super(line, offset)
                if DSNText.replace_inside_string(line) =~ REG_BLOCK_END_FORMAT
                    return true
                end
            else
                super("", offset)
            end

            return false
        end

        # event do構文解析処理
        #@param [String] line DSN記述の文字列一行
        #@param [Integer] offset 文字列の先頭行数
        #@return [Boolean] true : 構文解析開始前|終了後 false : 構文解析途中
        #
        def _parse_for_eventdo(line, offset)
            eventdo = nil
            new_eventdo = EventsDo.start_line?(line)
            last_eventdo = @event_do_blocks.last

            if last_eventdo.nil? || last_eventdo.is_end?
                if not new_eventdo.nil?
                    @event_do_blocks << new_eventdo
                    eventdo = new_eventdo
                end
            else
                # 解釈中のeventブロック中で、「～ do」と一致
                if not new_eventdo.nil?
                    # event doブロックの入れ子定義
                    raise DSNInternalFormatError, ErrorMessage::ERR_NESTED_EVENTDO
                end
                eventdo = last_eventdo
            end

            if eventdo.nil? || eventdo.is_end?
                return true
            else
                eventdo.parse_line(line, offset)
                # line=~/end/ でも、event doブロックのendなので、bloom doの解析終了ではない
                return false
            end
        end

        # 構文内部解析処理
        #
        #@param [StateDo] state doブロック解析クラス
        #@raise [DSNFormatError] 構文として正しくないデータが設定された。
        #@return [BloomDo] BloomDoクラスのインスタンス
        #@raise [DSNFormatError] 構文として正しくないデータが設定された。
        #
        def parse_inside(state)
            log_debug(){"#{@dsn_text}"}
            @dsn_text.delete(0)     # state do
            @dsn_text.delete(-1)    # end

            #servicelinks構文(transmission & trigger)の設定をおこなう。
            @service_link = ServiceLinks.new()
            @service_link.parse_inside(@dsn_text, state, @syntax_name)

            #event doブロックの設定をおこなう。
            @event_do_blocks.each do |eventdo|
                eventdo.parse_inside(state)
            end

            #event条件に登場するイベント名が、自ブロック以外のtrigger内で定義済み
            @event_do_blocks.each do |eventdo|
                event_names_from_eventdo = eventdo.get_event_names()
                log_debug(){"#{event_names_from_eventdo}"}
                event_names_from_trigger = _gather_event_name_in_trigger(eventdo)
                log_debug(){"#{event_names_from_trigger}"}
                if not (event_names_from_eventdo - event_names_from_trigger).empty?
                    raise DSNFormatError.new(ErrorMessage::ERR_EVENT_UNDEFINED, eventdo.dsn_text)
                end
            end

            return self
        rescue DSNInternalFormatError => err
            log_error err.backtrace.join("\n")
            raise DSNFormatError.new(err.message, @dsn_text)
        end

        # 自分以外のevent doブロックとbloom doのtriggerから、event_nameを収集する
        #@param [EventsDo] event doブロック解析クラス
        #
        def _gather_event_name_in_trigger(self_eventdo)
            event_names = @service_link.trigger_set.keys
            @event_do_blocks.each do |eventdo|
                next if self_eventdo.equal?(eventdo)
                event_names.concat eventdo.service_link.trigger_set.keys
            end
            return event_names.uniq
        end

        # BloomDo部分を中間コードに変換する。
        #
        #@param なし
        #@return [Hash] bloom doブロックの中間コード
        #@example
        #
        def to_hash()
            result = @service_link.to_hash

            # EventsDo部分を中間コードに変換する。
            events_do_hash_array = []
            @event_do_blocks.each do |events_do|
                events_do_hash_array << events_do.to_hash
            end
            result[KEY_EVENTS] = events_do_hash_array
            return result
        end

    end
end
