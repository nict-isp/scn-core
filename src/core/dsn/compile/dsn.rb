# -*- coding: utf-8 -*-
require_relative './dsn_text'
require_relative './state_do'
require_relative './bloom_do'
require_relative './dsn_define'
require_relative './dsn_text_parser'

module DSN

    #= DSN記述解釈クラス
    # DSN記述を解釈し、中間コードの変換する。
    #
    #@author NICT
    #
    class DSN < Syntax

        #@return [String] DSN記述の構成要素名
        attr_reader :syntax_name

        #@param [StateDo] state doブロックを取り扱うクラスのインスタンス
        #@param [BloomDo] bloom doブロックを取り扱うクラスのインスタンス
        #@param [String] overlay_name オーバーレイ名
        #
        def initialize(overlay_name)
            super()
            @syntax_name = "DSN"

            @state_do = nil
            @bloom_do = nil
            @overlay_name = overlay_name
        end

        # DSN記述を解釈するための下位のインスタンスを生成する。
        #
        #@param [DSNText] text DSN記述全体
        #@param [String] overlay_name オーバーレイ名
        #@example
        # state do
        #  @service_name: discovery(attr_name=attr_value, attr_name=attr_value...)
        #  @service_name: discovery(attr_name=attr_value, attr_name=attr_value...)
        #
        #  scratch: scratch_name, @service_name =>
        #                       [data_name, data_name,...]
        #
        #  channel: channel_name, @service_name => [data_name, data_name...]
        # end
        # bloom do
        #   …
        # end
        #
        #@return [DSN] DSNクラスのインスタンス
        #@raise [DSNFormatError] 構文として正しくないデータが設定された。
        #
        def self.parse(text, overlay_name)
            dsn = DSN.new(overlay_name)

            dsn.parse_inside(text)

            return dsn
        end

        def parse_inside(text)
            structures = []
            structures << Syntax.get_structure_class("DSN::StateDo")
            structures << Syntax.get_structure_class("DSN::BloomDo")

            parser = DSNTextParser.new(structures)
            syntax_elements = parser.parse_lines(text)

            statedo = syntax_elements.select {|elm| elm.is_a?(StateDo)}
            case statedo.size
            when 1
                @state_do = statedo[0]
                @state_do.parse_inside()
            when 0
                raise DSNFormatError.new(ErrorMessage::ERR_NO_STATE, text)
            else # >= 2
                raise DSNFormatError.new(ErrorMessage::ERR_MULTI_STATE, text)
            end

            bloomdo = syntax_elements.select {|elm| elm.is_a?(BloomDo)}
            case bloomdo.size
            when 1
                @bloom_do = bloomdo[0]
                @bloom_do.parse_inside(@state_do)
            when 0
                raise DSNFormatError.new(ErrorMessage::ERR_NO_BLOOM, text)
            else # >= 2
                raise DSNFormatError.new(ErrorMessage::ERR_MULTI_BLOOM, text)
            end

        end

        # DSN記述を中間コードに変換する。
        #
        #@param なし
        #@return [Hash<String,String>] DSN記述の中間コード
        #@example
        #    "overlay":"sample1",
        #    "services": {
        #        "@service_name1":{"attr_name11": "attr_value11", "attr_name12" : "attr_value12",…},
        #        "@service_name2":{"attr_name21": "attr_value21", "attr_name22": "attr_value22",…},
        #         …
        #    },
        #    "service_links":{…
        #
        def to_hash()
            #overlayキーワード部分を生成する。
            dsn = {KEY_OVERLAY => @overlay_name}

            #servicesキーワード部分を生成する。
            state_do = @state_do.to_hash
            dsn.merge!(state_do)

            bloom_do = @bloom_do.to_hash
            dsn.merge!(bloom_do)
            return dsn
        end

    end
end
