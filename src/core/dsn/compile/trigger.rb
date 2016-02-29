# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative './discovery'
require_relative './dsn_text'
require_relative './dsn_define'
require_relative './conditions'
require 'pp'

module DSN

    #= データ転送クラス
    # DSN記述のtransmission構文を中間コードに変換する。
    #
    #@author NICT
    #
    class Trigger < Syntax

        METHOD_NAME = "trigger"

        #@return [String] ON条件,OFF条件のステータス
        attr_reader :on_off_state
        #@return [String] イベント名
        attr_reader :event_name
        #@return [Communication] 対応するチャンネルインスタンス
        attr_reader :channel
        #@return [String] インターバル
        attr_reader :interval
        #@return [Conditions] trigger countに対する条件
        attr_reader :trigger_conditions
        #@return [Conditions] 判定条件
        attr_reader :conditions

        #@param [String] on_off_state ON条件,OFF条件のステータス
        #@param [String] event_name イベント名
        #@param [Communication] channel 対応するチャンネルインスタンス
        #@param [String] interval インターバル
        #@param [DSNText] trigger countに対する条件
        #@param [DSNText] conditions 判定条件
        #
        def initialize()
            super()
            @syntax_name = "trigger"
            @continued_line = "" # 前の行からの続き
        end

        # 構文開始判定処理
        #
        #@param [String] line DSN記述の文字列一行
        #@return [Syntax] DSN記述構文サブクラスのインスタンス
        #@return [nil] 構文開始条件不成立
        #
        def self.start_line?(line)
            log_trace(line)
            if DSNText.replace_inside_string(line) =~ REG_TRIGGER_START_FORMAT
                return Trigger.new()
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
            super(line, offset)

            left_line = @continued_line
            left_line << line

            if @event_name.nil?
                left_line = _parse_event_name(left_line)
            end

            if @trigger_line.nil?
                left_line = _parse_trigger(left_line)
                if left_line.size == 0
                    return true
                else
                    @continued_line = left_line
                    return false
                end
            end
        end

        # event名解析処理
        #
        #@param [String] line DSN記述の文字列一行
        #@return [String] 未解析文字列
        #
        def _parse_event_name(line)
            @event_name, left_line = DSNText.split(line, "<", 2, false)
            # start_lineでmatch後の呼び出しのため、event_nameの妥当性はチェック不要
            log_debug(){"#{left_line}"}
            case left_line.slice!(0)
            when "+"
                @on_off_state = TRIGGER_ON_DELIMITER
            when "-"
                @on_off_state = TRIGGER_OFF_DELIMITER
            else
                # バグ以外ありえない
            end

            return left_line.strip
        end

        # trigger解析処理
        #
        #@param [String] line DSN記述の文字列一行
        #@return [String] 未解析文字列
        #
        def _parse_trigger(line)
            left_line = ""
            if line =~ /trigger\s*\(/
                if DSNText.close_small_brackets?(line)
                    @trigger_line = line
                    left_line = ""
                else
                    left_line = line
                end
            else
                raise DSNFormatError.new("Invalid format of trigger.", @dsn_text)
            end
            return left_line
        end

        # 構文内部解析処理
        #
        #@param [StateDo] state DSN記述のstate doブロックを管理するインスタンス
        #@example
        #  event_name <+ scratch_name.trigger(interval, trigger_conditions,  condtions)
        #@return [Trigger] Triggerクラスのインスタンス
        #@raise [DSNFormatError] trigger構文として正しくないデータが設定された。
        #
        def parse_inside(state)
            # イベント名の名称と予約語チェック
            temp_event_name = BaseMethod.dataname_check(@event_name)
            if BaseMethod.reserved?(temp_event_name)
                raise DSNInternalFormatError.new(ErrorMessage::ERR_USE_RESERVED)
            end
            @event_name = temp_event_name

            reg = REG_PROCESSING_FORMAT.match(@trigger_line)
            trigger_text = DSNText.new(@dsn_text.text, @dsn_text.line_offset, reg["processing"])

            right_data = Trigger.get_right_data(trigger_text)
            channel_name = reg["scratch_name"]
            @channel = state.get_channel(channel_name)
            if @channel.nil?
                raise DSNFormatError.new(ErrorMessage::ERR_TRIGGER_FORMAT, channel_name)
            end
            @interval = right_data[0].single_line
            trigger_conditions_line = right_data[1]
            conditions_line = right_data[2]

            # trigger_conditionsがSignConditionでない場合、
            # またデータ名にcount以外が設定されていた場合は
            # エラーとする
            if SignCondition.match?(trigger_conditions_line)
                @trigger_conditions = SignCondition.parse(trigger_conditions_line)
                dataname = @trigger_conditions.data_name
                unless dataname == "count"
                    msg = "input: #{dataname}"
                    raise DSNFormatError.new(ErrorMessage::ERR_TRIGGER_CONDITION, trigger_conditions_line, msg)
                end
            else
                raise DSNFormatError.new(ErrorMessage::ERR_TRIGGER_FORMAT, trigger_conditions_line)

            end

            @conditions = Conditions.parse(conditions_line)

            # intervalが正の整数でない場合はエラーとする
            # (整数であることはsplit_trigger内で確認済み)
            if @interval <= 0
                msg = "interval: #{@interval}"
                raise DSNFormatError.new(ErrorMessage::ERR_TRIGGER_INTERVAL, trigger_text, msg)
            end

            return self
        rescue DSNInternalFormatError => err
            log_error err.backtrace.join("\n")
            raise DSNFormatError.new(err.message, @dsn_text)
        end

        #---
        # DSN記述のtrigger構文を1行解釈する。
        #
        #@param [DSNText] text DSN記述のtrigger構文
        #@param [StateDo] state DSN記述のstate doブロックを管理するインスタンス
        #@example
        #  channel_name <+ trigger(scratch_name, interval, trigger_conditions,  condtions)
        #@return [Trigger] Triggerクラスのインスタンス
        #@raise [DSNFormatError] trigger構文として正しくないデータが設定された。
        #
        def self.parse(text, state)
            #改行コードを削除して、1行にする。
            text.convert_single_line

            #transmission構文を左辺と右辺に分解する。
            left, right, on_off_state = split_trigger(text)

            #右辺のデータから、channel名他を決定する。
            right_data = get_right_data(right)
            channel = state.get_channel(right_data[0].single_line)
            interval = right_data[1].single_line
            trigger_conditions = right_data[2]
            conditions = right_data[3]

            # trigger_conditionsがSignConditionでない場合、
            # またデータ名にcount以外が設定されていた場合は
            # エラーとする
            if SignCondition.match?(trigger_conditions)
                dataname = SignCondition.parse(trigger_conditions).data_name
                unless dataname == "count"
                    msg = "input: #{dataname}"
                    raise DSNFormatError.new(ErrorMessage::ERR_TRIGGER_CONDITION, trigger_conditions, msg)
                end
            else
                raise DSNFormatError.new(ErrorMessage::ERR_TRIGGER_FORMAT, trigger_conditions)

            end

            # intervalが正の整数でない場合はエラーとする
            # (整数であることはsplit_trigger内で確認済み)
            if interval <= 0
                msg = "interval: #{interval}"
                raise DSNFormatError.new(ErrorMessage::ERR_TRIGGER_INTERVAL, text, msg)
            end

            return Trigger.new( on_off_state, left.single_line,
            channel, interval,
            trigger_conditions,
            conditions)
        end

        #ON条件、OFF条件で右辺左辺に分割する。
        #
        #@param [DSNText] dsn_text 対象のテキスト
        #@return [Array<DSNText>] 左辺、右辺に分解したテキスト
        #
        def self.split_trigger(dsn_text)
            case
            when dsn_text.single_line =~ /#{REG_TRIGGER_ON_DELIMITER}/
                left, right = DSNText.split_two_on_trigger(dsn_text)
                state = TRIGGER_ON_DELIMITER
            when dsn_text.single_line =~ /#{REG_TRIGGER_OFF_DELIMITER}/
                left, right = DSNText.split_two_off_trigger(dsn_text)
                state = TRIGGER_OFF_DELIMITER
            else
                #エラー処理
            end
            return left, right, state
        end

        #右辺のデータから、scratchインスタンスとprocessingインスタンスを読みだす。
        #
        #@param [String] text 右辺の文字列
        #@return [Array<DSNText>]
        #
        def self.get_right_data( text)
            format = [[TYPE_INTEGER], [TYPE_ANY], [TYPE_ANY]]
            return BaseMethod.parse(text, METHOD_NAME, format)
        end

        # transmission構文を中間コードに変換する。
        #
        #@return [Hash<String,String>] 中間コード
        #
        def to_hash()
            return { KEY_TRIGGER_INTERVAL => @interval,
                KEY_TRIGGER_CONDITIONS => @trigger_conditions.to_hash,
                KEY_CONDITIONS => @conditions.to_hash,
                REG_CHANNEL_NAME => @channel.name}
        end

    end
end
