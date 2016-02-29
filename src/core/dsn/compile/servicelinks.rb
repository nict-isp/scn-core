# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative './dsn_text'
require_relative './transmission'
require_relative './trigger'
require_relative './merge'

module DSN

    #= チャネルクラス
    # DSN記述のservicelinkを管理する。
    #
    #@author NICT
    #
    class ServiceLinks

        #@return [Hash<String, Trigger>] trigger
        attr_reader :trigger_set

        #
        def initialize()
            @transmission_set = Hash.new(){|hash, key| hash[key] = []}
            @trigger_set      = Hash.new(){|hash,key| hash[key] = {"on" =>[], "off"=>[] }}
            @merge_set        = Hash.new(){|hash, key| hash[key] = []}
        end

        # DSN記述からTransmissionインスタンスの生成とTriggerSetインスタンスの生成をおこなう。
        #
        #@param [DSNText] text DSN記述のstate doブロックの中身
        #@param [StateDo] state StateDoクラスのインスタンス
        #@example
        #  channel_name1 <~ scratch_name1
        #  channel_name3 <~ filter(scratch_name4, condtions)
        #  event_name <+ trigger( channel_name1, trigger_interval, trigger_condtions,
        #  condtions)
        #
        #@return [ServiceSet] ServiceLinkクラスのインスタンス
        #@raise [DSNFormatError] 構文として正しくないデータが設定された。
        #
        def parse_inside(dsn_text, state, block_name)
            log_trace(dsn_text, state, block_name)

            structures = []
            structures << Syntax.get_structure_class("DSN::Transmission")
            structures << Syntax.get_structure_class("DSN::Trigger")
            structures << Syntax.get_structure_class("DSN::Merge")

            parser = DSNTextParser.new(structures)

            syntax_elements = parser.parse_lines(dsn_text)

            syntax_elements.each do |syntax|
                log_debug(){"#{syntax.class}"}
                case syntax.class.to_s
                when "DSN::Transmission"
                    trans = syntax.parse_inside(state)
                    @transmission_set[trans.servicelink()] << trans
                when "DSN::Trigger"
                    trigger = syntax.parse_inside(state)
                    _set_trigger(trigger)
                when "DSN::Merge"
                    merge = syntax.parse_inside(state)
                    @merge_set[merge.line_offset] = merge
                else
                    # バグ以外ありえない
                    raise "No match DSN syntax in #{block_name} block."
                end
            end

            return self
        rescue DSNInternalFormatError => err
            log_error err.backtrace.join("\n")
            raise DSNFormatError.new(err.message, @dsn_text)
        end

        # Triggerクラスのインスタンスをメンバ変数に設定する。
        #
        #@param [Trigger] trigger 格納対象のTriggerクラスのインスタンス
        #@raise [DSNFormatError] 構文として正しくないデータが設定された。
        #
        def _set_trigger(trigger)
            case trigger.on_off_state
            when TRIGGER_ON_DELIMITER
                @trigger_set[trigger.event_name]["on"] << trigger
            when TRIGGER_OFF_DELIMITER
                @trigger_set[trigger.event_name]["off"] << trigger
            else
                raise DSNFormatError.new(ErrorMessage::ERR_TRIGGER_FORMAT, trigger.on_off_state)
            end
            return
        end

        # チャネルの集合を中間コードに変換する。
        #
        #@param なし
        #@return [Hash] チャネルの集合の中間コード
        #@example
        #
        def to_hash()
            return {
                KEY_SERVICE_LINK => self._transmission_to_hash,
                KEY_TRIGGER      => self._trigger_to_hash,
                KEY_MERGES       => self._merge_to_hash
            }
        end

        # transmissionのハッシュを取得する。
        def _transmission_to_hash()
            #transmissionから,チャネルの一覧を取り出す。
            #チャネルの一覧に対して、各々のリンクに対応した中間コードを読みだす。
            array = []

            links = @transmission_set.keys
            links.each do |link|

                trans_array = @transmission_set[link]
                if trans_array.size > 0
                    trans = trans_array[0]
                end

                processings = []
                trans_array.each do |data|
                    data.processings.each do |processing|
                        processings << processing.to_hash
                    end
                end

                servicelink = trans.to_hash
                servicelink.merge!({
                    KEY_APP_REQUEST => {
                    KEY_PROCESSING => processings,
                    KEY_CHANNEL    => trans.channel.to_hash(trans.select.hash_empty, trans.meta.hash_empty),
                    KEY_SCRATCH    => trans.scratch.to_hash(trans.select.to_hash(),  trans.meta.to_hash()),
                    KEY_QOS        => trans.qos.to_hash(),
                    KEY_ID         => trans.id.to_hash()
                    }
                })
                array << servicelink
            end

            return array
        end

        # triggerのハッシュを取得する。
        def _trigger_to_hash()
            hash = Hash.new() { |hash,key| hash[key] = {} }

            @trigger_set.each do |event_name, triggers|
                hash[event_name]["on"]  = triggers["on"].map{  |trigger| trigger.to_hash() }
                hash[event_name]["off"] = triggers["off"].map{ |trigger| trigger.to_hash() }
            end

            return hash
        end

        # mergeのハッシュを取得する。
        def _merge_to_hash()
            array = []
            @merge_set.each do |key, merge|
                array << merge.to_hash
            end

            return array
        end
    end
end
