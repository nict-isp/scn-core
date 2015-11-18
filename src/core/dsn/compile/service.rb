# -*- coding: utf-8 -*-
require_relative './discovery'
require_relative './dsn_text'
require_relative './dsn_define.rb'

module DSN

    #= サービスクラス
    # DSN記述のdiscovery構文を中間コードに変換する。
    #
    #@author NICT
    #
    class Service < Syntax

        #@return [String] サービス名
        attr_reader :name
        #@return [Hash<String,Array<String>>] キー:attr_name, 値:[attr_value1,…]
        attr_reader :attr_data

        #@param [String] サービス名
        #@param [Hash<String,Array<String>>] キー:attr_name, 値:[attr_value1,…]
        #
        def initialize()
            super()
            @syntax_name = "service"
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
            if DSNText.replace_inside_string(line) =~ REG_SERVICE_START_FORMAT
                return Service.new()
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

        # サービス名解析処理
        #
        #@param [String] line DSN記述の文字列一行
        #@return [String] 未解析文字列
        #
        def _parse_name(line)
            log_trace(line)
            @name, left_line = DSNText.split(line, ":", 2, false)
            # start_lineでmatch後の呼び出しのため、@nameの妥当性はチェック不要
            if left_line.nil?
                left_line = ""
            end
            return left_line
        end

        # 情報抽出解析処理
        #
        #@param [String] line DSN記述の文字列一行
        #@return [String] 未解析文字列
        #
        def _parse_attr_data(line)
            log_trace(line)
            line.strip!
            return line if line.size == 0 # 次の行に継続と判断

            if DiscoveryMethod.is_method?(line)
                if line[-1] == ")"
                    method_text = DSNText.new(@dsn_text.text, @dsn_text.line_offset, line)
                    @attr_data = DiscoveryMethod.parse(method_text)
                    return ""
                else
                    return line # 次の行に継続と判断
                end
            else
                raise DSNInternalFormatError, ErrorMessage::ERR_DISCOVERY_FORMAT
            end
        end

        # 構文内部解析処理
        def parse_inside()
            # サービス名チェックは構文を取り出した時点で
            # 済んでいるため不要、予約語確認も必要なし

            return self
        rescue DSNInternalFormatError => err
            log_error err.backtrace.join("\n")
            raise DSNFormatError.new(err.message, @dsn_text)
        end

        # discovery構文を中間コードに変換する。
        #
        #@param なし
        #@return [Hash<String,Hash>] discovery構文の中間コード
        #@example
        #   {"@service_name1":{"attr_name1":"attr_value1", "attr_name2":"attr_value2"}}
        #
        #
        def to_hash()
            return {@name => @attr_data}
        end

    end
end
