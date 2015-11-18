# -*- coding: utf-8 -*-
require_relative './discovery'
require_relative './dsn_text'
require_relative './dsn_define'
require_relative './filter_method'
require_relative './cull_time_method'
require_relative './cull_space_method'
require_relative './aggregate_method'
require_relative './select_method'
require_relative './meta_method'
require_relative './qos_method'
require_relative './id_method'

module DSN

    #= データ転送クラス
    # DSN記述のtransmission構文を中間コードに変換する。
    #
    #@author NICT
    #
    class Transmission < Syntax

        #右辺値の解析結果を返すハッシュのキー
        SCRATCH_DATA = "scratch"
        PROCESSING_DATA = "processing"

        #@return [Communication] 対応するチャンネルのインスタンス
        attr_reader :channel
        #@return [Communication] 対応するスクラッチのインスタンス
        attr_reader :scratch
        #@return [Integer] DSN記述の行数
        attr_reader :line_offset
        #@return [Array<Processing>] 実施されるメソッドに対応するインスタンス
        attr_reader :processings
        #@return [SelectMethod] selectメソッドに対応するインスタンス
        attr_reader :select
        #@return [QoSMethod] QoSメソッドに対応するインスタンス
        attr_reader :qos
        #@return [MetaMethod] metaメソッドに対応するインスタンス
        attr_reader :meta
        #@return [IDMethod] idメソッドに対応するインスタンス
        attr_reader :id

        #@param [Communication] channel 対応するチャンネルのインスタンス
        #@param [Communication] scratch 対応するスクラッチのインスタンス
        #@param [Processing] processing 実施されるメソッドに対応するインスタンス
        #
        def initialize()
            super()
            @syntax_name    = "transmission"
            @continued_line = "" # 前の行からの続き

            @processings    = []
            @select         = SelectMethod.new(nil)
            @meta           = MetaMethod.new(nil)
            @qos            = QoSMethod.new(nil, nil)
            @id             = IDMethod.new(nil)
        end

        # 構文開始判定処理
        #
        #@param [String] line DSN記述の文字列一行
        #@return [Syntax] DSN記述構文サブクラスのインスタンス
        #@return [nil] 構文開始条件不成立
        #
        def self.start_line?(line)
            log_trace(line)
            if DSNText.replace_inside_string(line) =~ REG_TRANSMISSION_START_FORMAT
                return Transmission.new()
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

        # channel名解析処理
        #
        #@param [String] line DSN記述の文字列一行
        #@return [String] 未解析文字列
        #
        def _parse_channel(line)
            @channel_name, left_line = DSNText.split(line, "<~", 2, false)
            # start_lineでmatch後の呼び出しのため、channel_nameの妥当性はチェック不要
            if left_line.nil?
                left_line = ""
            end
            return left_line
        end

        # scratch名解析処理
        #
        #@param [String] line DSN記述の文字列一行
        #@return [String] 未解析文字列
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

        # 構文内部解析処理
        #
        #@param [StateDo] state DSN記述のstate doブロックを管理するインスタンス
        #@example
        #  channel_name <~ scratch_name
        #  channel_name <~ filter(scratch_name, condtions)等
        #@return [Transmission] Transmissionクラスのインスタンス
        #@raise [DSNFormatError] transmission構文として正しくないデータが設定された。
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

        # 中間処理構文解析処理
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
            when SelectMethod.match?(proc_text)
                method["select"]     = SelectMethod.parse(proc_text)
            when MetaMethod.match?(proc_text)
                method["meta"]       = MetaMethod.parse(proc_text)
            when QoSMethod.match?(proc_text)
                method["qos"]        = QoSMethod.parse(proc_text)
            when IDMethod.match?(proc_text)
                method["id"]         = IDMethod.parse(proc_text)
            else
                # transmission構文として取り得ないメソッドの場合
                if /^(\w+)\(.*\)$/ =~ @processing_line
                    msg = "method: #{$1}"
                else
                    msg = ""
                end
                raise DSNFormatError.new(ErrorMessage::ERR_TRANSMISSION_METHOD, proc_text, msg)
            end
            return method
        end

        # チャネル識別名
        #
        #@return [String] チャネルを指定する名称
        #
        def servicelink()
            return "#{@line_offset}:#{@channel_name}<~#{@scratch_name}"
        end

        #中間コードを生成する。
        #
        #@return [Hash<String,String>] 中間コード(src,dst)
        #
        def to_hash()
            return { KEY_TRANS_SRC => @scratch.service_name,
                KEY_TRANS_DST => @channel.service_name }
        end

    end
end
