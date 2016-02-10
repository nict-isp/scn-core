# -*- coding: utf-8 -*-
require_relative './dsn_text'
require_relative './dsn_define'
require_relative './merge_method'
require_relative './join_method'

module DSN

    #= データマージクラス
    # DSN記述のmerge構文を中間コードに変換する。
    #
    #@author NICT
    #
    class Merge < Syntax

        #@return [Communication] 対応するチャンネルのインスタンス
        attr_reader :channel
        #@return [Integer] DSN記述の行数
        attr_reader :line_offset

        #@param [Communication] channel 対応するチャンネルのインスタンス
        #@param [Communication] scratch 対応するスクラッチのインスタンス
        #@param [Processing] processing 実施されるメソッドに対応するインスタンス
        #
        def initialize()
            super()
            @syntax_name    = "merge"
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
            if DSNText.replace_inside_string(line) =~ REG_MERGE_START_FORMAT
                return Merge.new()
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
        end

        # channel名解析処理
        #
        #@param [String] line DSN記述の文字列一行
        #@return [String] 未解析文字列
        #
        def _parse_channel(line)
            @channel_name, left_line = DSNText.split(line, ".", 2, false)
            # start_lineでmatch後の呼び出しのため、channel_nameの妥当性はチェック不要
            if left_line.nil?
                left_line = ""
            end
            return left_line
        end

        # 構文内部解析処理
        #
        #@param [StateDo] state DSN記述のstate doブロックを管理するインスタンス
        #@example
        #  channel_name1.merge(10, channel_name2, channel_name3)
        #@return [Transmission] Transmissionクラスのインスタンス
        #@raise [DSNFormatError] transmission構文として正しくないデータが設定された。
        #
        def parse_inside(state)

            # channel名の定義チェック
            @channel = state.get_channel(@channel_name)
            if @channel.nil?
                raise DSNFormatError.new(ErrorMessage::ERR_CHANNEL_UNDEFINED, @dsn_text, @channel_name)
            end

            reg = REG_PROCESSING_FORMAT.match(@continued_line)
            if not reg.nil?()
                dsn_processings = DSNText.split(reg["processing"], ".")
                # 先頭はマージ処理
                processing      = dsn_processings.shift
                @merge_method   = _parse_merge(processing)
                # マージの後に続くメソッドを処理
                dsn_processings.each do |processing|
                    method = _parse_method(processing)
                    @processings << method["processing"]  if method.has_key?("processing")
                    @select      =  method["select"]      if method.has_key?("select")
                    @meta        =  method["meta"]        if method.has_key?("meta")
                    @qos         =  method["qos"]         if method.has_key?("qos")
                    @id          =  method["id"]          if method.has_key?("id")
                end
            else
                raise DSNFormatError.new(ErrorMessage::ERR_MERGE_METHOD, @continued_line)
            end

            # channel名の定義チェック（mergeメソッド内）
            @merge_method.to_hash()[KEY_MERGE_SRC].each do |channel_name|
                channel = state.get_channel(channel_name)
                if channel.nil?
                    raise DSNFormatError.new(ErrorMessage::ERR_CHANNEL_UNDEFINED, @dsn_text, channel_name)
                end
            end

            return self

        rescue DSNInternalFormatError => err
            log_error err.backtrace.join("\n")
            raise DSNFormatError.new(err.message, @dsn_text)
        end

        # マージ構文解析処理
        def _parse_merge(processing)
            method    = nil
            proc_text = DSNText.new(@dsn_text.text, @dsn_text.line_offset, processing)

            case
            when MergeMethod.match?(proc_text)
                method = MergeMethod.parse(proc_text)
            when JoinMethod.match?(proc_text)
                method = JoinMethod.parse(proc_text)
            else
                # 必ずマッチするはず。
            end
            return method
        end

        # 中間処理構文解析処理（マージ用）
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
            #when AggregateMethod.match?(proc_text)
            #    method["processing"] = AggregateMethod.parse(proc_text)
            when StringMethod.match?(proc_text)
                method["processing"] = StringMethod.parse(proc_text)
            when VirtualMethod.match?(proc_text)
                method["processing"] = VirtualMethod.parse(proc_text)
            when SelectMethod.match?(proc_text)
                method["select"]     = SelectMethod.parse(proc_text)
            #when MetaMethod.match?(proc_text)
            #    method["meta"]       = MetaMethod.parse(proc_text)
            #when QoSMethod.match?(proc_text)
            #    method["qos"]        = QoSMethod.parse(proc_text)
            #when IDMethod.match?(proc_text)
            #    method["id"]         = IDMethod.parse(proc_text)
            else
                # transmission構文として取り得ないメソッドの場合
                if /^(\w+)\(.*\)$/ =~ @processing_line
                    msg = "method: #{$1}"
                else
                    msg = ""
                end
                raise DSNFormatError.new(ErrorMessage::ERR_MERGE_PROCESSING_METHOD, proc_text, msg)
            end
            return method
        end

        #中間コードを生成する。
        #
        #@return [Hash<String,String>] 中間コード(src,dst)
        #
        def to_hash()
            hash = @merge_method.to_hash()
            hash[KEY_MERGE_DST] = @channel_name
            hash[KEY_APP_REQUEST] = {
                KEY_PROCESSING => @processings.map{|processing| processing.to_hash()},
                KEY_SELECT     => @select.to_hash(),
                KEY_META       => @meta.to_hash(),
                KEY_QOS        => @qos.to_hash(),
                KEY_ID         => @id.to_hash(),
            }
            return hash
        end

    end
end
