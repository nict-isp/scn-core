# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative './dsn_text'
require_relative './dsn_define'

module DSN

    #= scratch,channel構文解析クラス
    # DSN記述のscratch,channel構文を解析する。
    #
    #@author NICT
    #
    class Communication < Syntax

        #@return [String] コミュニケーション名(scratch名,channel名)
        attr_reader :name
        #@return [String] サービス名
        attr_reader :service_name
        #@return [String] DSN記述の構成要素名
        attr_reader :syntax_name

        #
        def initialize()
            super()
            @continued_line = "" # 前の行からの続き
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

            if @name.nil?
                left_line = _parse_name(left_line)
            end
            if @service_name.nil?
                left_line = _parse_service_name(left_line)
            end

            if @name && @service_name
                if left_line.size == 0
                    return true
                else
                    @continued_line = left_line
                    return false
                end
            else
                return false
            end
        end

        # コミュニケーション名(scratch名,channel名)解析処理
        #
        #@param [String] line DSN記述の文字列一行
        #@return [String] 未解析文字列
        #
        def _parse_name(line)
            syntax, left_line = DSNText.split(line, ":", 2, false)
            # start_lineでmatch後の呼び出しのため、syntaxの妥当性はチェック不要
            if left_line.nil?
                left_line = ""
            else
                @name, left_line = DSNText.split(left_line, ",", 2, false)
                if left_line.nil?
                    left_line = ""
                end
            end
            return left_line
        end

        # サービス名解析処理
        #
        #@param [String] line DSN記述の文字列一行
        #@return [String] 未解析文字列
        #
        def _parse_service_name(line)
            @service_name, left_line = DSNText.split(line, "=>", 2, false)
            left_line = ""
            return left_line
        end

        # 構文内部解析処理
        def parse_inside()
            # scratch,channel名の名称と予約語チェック
            temp_name = BaseMethod.dataname_check(@name)
            if BaseMethod.reserved?(temp_name)
                raise DSNInternalFormatError.new(ErrorMessage::ERR_USE_RESERVED)
            end
            @name = temp_name

            # サービス名のフォーマットチェック(@ではじまるデータ名)
            if @service_name.slice(0) == "@"
                temp_name = @service_name.slice(1..-1)
                temp_name = BaseMethod.dataname_check(temp_name)
            else
                msg = "Service name format does not correct."
                raise DSNInternalFormatError.new(msg)

            end

            return self
        rescue DSNInternalFormatError => err
            log_error err.backtrace.join("\n")
            raise DSNFormatError.new(err.message, @dsn_text)
        end

        # scratch, channel構文を中間コードに変換する。
        #@param [Hash] select_hash selectメソッドの中間コード
        #@param [Hash] meta_hash metaメソッドの中間コード
        #@return [Hash] scratch, channel構文の中間コード
        #
        def to_hash(select_hash, meta_hash)
            return {
                KEY_SELECT_NAME => @name,
                KEY_SELECT      => select_hash,
                KEY_META        => meta_hash
            }
        end
    end

    class Scratch < Communication

        def initialize()
            super
            @syntax_name = "scratch"
        end

        # 構文開始判定処理
        #
        #@param [String] line DSN記述の文字列一行
        #@return [Syntax] DSN記述構文サブクラスのインスタンス
        #@return [nil] 構文開始条件不成立
        #
        def self.start_line?(line)
            log_trace(line)
            if DSNText.replace_inside_string(line) =~ REG_SCRATCH_START_FORMAT
                return Scratch.new()
            else
                return nil
            end
        end
    end

    class Channel < Communication

        #
        def initialize()
            super
            @syntax_name = "channel"
        end

        # 構文開始判定処理
        #
        #@param [String] line DSN記述の文字列一行
        #@return [Syntax] DSN記述構文サブクラスのインスタンス
        #@return [nil] 構文開始条件不成立
        #
        def self.start_line?(line)
            log_trace(line)
            if DSNText.replace_inside_string(line) =~ REG_CHANNEL_START_FORMAT
                return Channel.new()
            else
                return nil
            end
        end

    end
end
