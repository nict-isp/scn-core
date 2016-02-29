# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative './service'
require_relative './communication'
require_relative './dsn_text'

module DSN

    #= StateDoブロッククラス
    # DSN記述のstate doブロックを管理する。
    #@author NICT
    #
    class StateDo < Syntax

        #@param [ServiceSet] services discovery構文の集合を取り扱うクラスのインスタンス
        #@param [CommunicationSet] scratches scratch構文の集合を取り扱うクラスのインスタンス
        #@param [CommunicationSet] channels channel構文の集合を取り扱うクラスのインスタンス
        #
        def initialize()
            super()
            @name = "state do"

            @services  = {}
            @scratches = {}
            @channels  = {}
        end

        # 構文開始判定処理
        #
        #@param [String] line DSN記述の文字列一行
        #@return [Syntax] DSN記述構文サブクラスのインスタンス
        #@return [nil] 構文開始条件不成立
        #
        def self.start_line?(line)
            log_trace(line)
            if DSNText.replace_inside_string(line) =~ REG_STATE_BLOCK_FORMAT
                return StateDo.new()
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

            return DSNText.replace_inside_string(line) =~ REG_BLOCK_END_FORMAT
        end

        #構文内部解析処理
        #
        #@param なし
        #@raise [DSNFormatError] 構文として正しくないデータが設定された。
        #
        def parse_inside()
            log_debug(){"#{@dsn_text}"}
            @dsn_text.delete(0)     # state do
            @dsn_text.delete(-1)    # end

            structures = []
            structures << Syntax.get_structure_class("DSN::Service")
            structures << Syntax.get_structure_class("DSN::Scratch")
            structures << Syntax.get_structure_class("DSN::Channel")
            parser = DSNTextParser.new(structures)

            syntax_elements = parser.parse_lines(@dsn_text)
            syntax_elements.each do |syntax|
                log_debug(){"#{syntax.class}"}
                case syntax.class.to_s
                when "DSN::Service"
                    service = syntax.parse_inside()
                    if @services.key?(service.name)
                        raise DSNFormatError.new(ErrorMessage::ERR_SERVICE_DUPLICATE, @dsn_text, service.name)
                    else
                        @services[service.name] = service
                    end
                when "DSN::Scratch"
                    scratch = syntax.parse_inside()
                    if @scratches.key?(scratch.name)
                        raise DSNFormatError.new(ErrorMessage::ERR_SCRATCH_DUPLICATE, @dsn_text, scratch.name)
                    else
                        @scratches[scratch.name] = scratch
                    end
                when "DSN::Channel"
                    channel = syntax.parse_inside()
                    if @channels.key?(channel.name)
                        raise DSNFormatError.new(ErrorMessage::ERR_CHANNEL_DUPLICATE, @dsn_text, channel.name)
                    else
                        @channels[channel.name] = channel
                    end
                else
                    raise DSNInternalFormatError, "No match DSN syntax in state do block."
                end

            end
        rescue DSNInternalFormatError => err
            log_error err.backtrace.join("\n")
            raise DSNFormatError.new(err.message, @dsn_text)
        end

        # サービス部分を中間コードに変換する。
        #
        #@param なし
        #@return [Hash] discovery構文の集合の中間コード
        #@example
        #    "services": {
        #        "@service_name1":{"attr_name11": "attr_value11", "attr_name12" : "attr_value12",…},
        #        "@service_name2":{"attr_name21": "attr_value21", "attr_name22": "attr_value22",…},
        #         …
        #    }
        #
        def to_hash()
            services_hash = {}
            @services.each_value do |service|
                services_hash[service.name] = service.attr_data
            end
            return {KEY_SERVICES => services_hash}
        end

        # チャンネル名から、チャンネルのインスタンスを取得する。
        #
        #@param [DSNText] name channelを指定する名前
        #@return [Communication] チャンネル名に対応するインスタンス
        #
        def get_channel(name)
            return @channels[name]
        end

        # スクラッチ名から、スクラッチのインスタンスを取得する。
        #
        #@param [DSNText] name scratchを指定する名前
        #@return [Communication] スクラッチ名に対応するインスタンス
        #
        def get_scratch(name)
            return @scratches[name]
        end

    end
end
