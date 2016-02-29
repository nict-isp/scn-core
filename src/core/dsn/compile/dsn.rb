# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative './dsn_text'
require_relative './state_do'
require_relative './bloom_do'
require_relative './dsn_define'
require_relative './dsn_text_parser'

module DSN

    #= DSN description interpretation class
    # Interprets the DSN description, it is converted into an intermediate code.
    #
    #@author NICT
    #
    class DSN < Syntax

        #@return [String] Component name of the DSN description
        attr_reader :syntax_name

        #@param [String] overlay_name  Overlay name
        #
        def initialize(overlay_name)
            super()
            @syntax_name = "DSN"

            @state_do = nil
            @bloom_do = nil
            @overlay_name = overlay_name
        end

        # To generate a lower instance for interpreting the DSN description.
        #
        #@param [DSNText] text          Whole DSN description
        #@param [String]  overlay_name  Overlay name
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
        #@return [DSN] Instance of DNS class
        #@raise [DSNFormatError] Incorrect data as the syntax is set
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

        # To convert the DSN description in the intermediate code.
        #
        #@return [Hash<String,String>] Intermediate code of DSN description
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
            # To generate the overlay keyword part.
            dsn = {KEY_OVERLAY => @overlay_name}

            # To generate the services keyword part.
            state_do = @state_do.to_hash
            dsn.merge!(state_do)

            bloom_do = @bloom_do.to_hash
            dsn.merge!(bloom_do)
            return dsn
        end

    end
end
