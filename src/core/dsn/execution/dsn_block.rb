# -*- coding: utf-8 -*-
require_relative '../../utils'
require_relative '../compile/dsn_define'
require_relative '../compile/conditions'
require_relative '../../translator/supervisor'
require_relative './channel_settings'

#= チャネル設定ブロッククラス
#  DSN記述の event_condition do ブロックの設定を保持する。
#
#@author NICT
#
class DSNEventBlock
    include DSN

    #@return [String] overlay ID
    attr_reader   :overlay
    #@return [Hash]          イベント成立条件
    attr_reader   :event_cond
    #@return [True]         イベント成立状態
    #@return [False]         イベント非成立状態
    attr_reader   :event_staｌte
    #@return [Array]         イベント成立時チャネル設定リスト
    attr_reader   :channel_settings
    #@return [Array]         イベント成立時状態監視
    attr_reader   :trigger

    #@param [Hash] DSN記述イベントコンディションブロック
    #@param [Hash] サービスブロック（ChannelSettings へ渡す）
    #
    def initialize(overlay, event_hash, services_hash)
        @overlay     = overlay
        @event_state = false
        @event_cond  = event_hash[KEY_CONDITIONS]
        @trigger     = event_hash[KEY_TRIGGER]

        @block = compile_conditions(@event_cond)
        parse_service_link(event_hash, services_hash)
    end

    #@param [Hash] trigger_hash DSN記述のトリガ設定
    #
    def merge_trigger(trigger_hash)
        log_debug{"#{trigger_hash}"}
        if trigger_hash.is_a?(Hash) && @trigger.is_a?(Hash)
            @trigger.each do |event_name, on_off|
                if not trigger_hash.include?(event_name)
                    trigger_hash[event_name] = {"on" => [], "off" => []}
                end
                event_trigger = trigger_hash[event_name]
                if @event_state == true
                    event_trigger["on"].concat(on_off["on"])
                    event_trigger["off"].concat(on_off["off"])
                end
            end
        end
        log_debug{"#{trigger_hash}"}
        return trigger_hash
    end

    #@param [Hash] overlay_info オーバーレイ情報
    #@return [Hash] ブロックの状態（ログ出力向け）
    #
    def update_state(events)
        log_debug{"#{events}"}
        # 条件成立確認
        @event_state = Conditions.ok?(@event_cond, events)

        update()
    end

    #@param [Hash] イベントコンディションブロック
    #@param [Hash] サービスブロック（ChannelSettings へ渡す）
    #
    def modify(event_hash, services_hash)
        log_debug(){"old_settings = #{@channel_settings}"}

        new_settings = []
        old_settings = @channel_settings.dup
        # 追加されているチャネルを、@channel_settingへ追加する。
        event_hash[KEY_SERVICE_LINK].each do |link_hash|
            new_setting = ChannelSettings.new(@overlay, link_hash, services_hash, @block)

            # 複数同じ要素がある場合を考慮し、delete_atを使用する
            old_index = old_settings.index(new_setting)
            if old_index.nil?
                old_index = old_index = old_settings.index{|setting| setting.same_channel?(new_setting) }
                if old_index.nil?
                    # 新規セッティング
                    new_settings << new_setting
                else
                    # srcとdstのみの一致
                    old_setting    = old_settings.delete_at(old_index)
                    new_setting.id = old_setting.id
                    new_setting.update()
                    new_settings << new_setting
                end
            else
                # 完全一致（操作不要）
                new_settings << old_settings.delete_at(old_index)
            end
        end
        @channel_settings = new_settings
        # 不要なチャネルを削除
        old_settings.each {|setting| setting.delete}

        log_debug(){"new_settings = #{@channel_settings}"}

        update()
    end

    private

    def update()
        if @event_state == true
            @channel_settings.each do |channel_setting|
                channel_setting.activate()
            end
        else
            @channel_settings.each do |channel_setting|
                channel_setting.inactivate()
            end
        end
    end

    #@param [Hash] イベントコンディションブロック
    #@param [Hash] サービスブロック（ChannelSettings へ渡す）
    #
    def parse_service_link(event_hash, services_hash)
        @channel_settings = []
        event_hash[KEY_SERVICE_LINK].each do |link_hash|
            begin
                @channel_settings << ChannelSettings.new(@overlay, link_hash, services_hash, @block)
            rescue
                log_error("", $!)
            end
        end
    end

    #@param [Hash] 単一のイベント成立条件
    #@return [String] 単一のイベント成立条件の文字列
    #
    def compile_condition(key, values)
        case values[1]
        when true
            result = "#{key}.on"
        when false
            result = "#{key}.off"
        else
            puts "error"
        end
        return result
    end

    #@return [String] イベント成立条件の文字列
    #
    def compile_conditions(conditions)
        return "" if conditions.nil?
        conditions.each do |key, values|
            case key
            when "-and"
                result = values.map{ |condition| compile_conditions(condition) }.join(" && ")
                result = "(#{result})"
            when "-or"
                result = values.map{ |condition| compile_conditions(condition) }.join(" || ")
                result = "(#{result})"
            else
                result = compile_condition(key, values)
            end
            return result   # 条件式のHashは1要素しか持たない
        end
    end
end

#= チャネル常時設定ブロッククラス
#  DSN記述の bloom do ブロックの設定を保持する。
#
class DSNConstantBlock < DSNEventBlock

    #@param [Hash] DSN記述イベントコンディションブロック
    #@param [Hash] サービスブロック（ChannelSettings へ渡す）
    #
    def initialize(id, event_hash, services_hash)
        super
        @event_state = true # 不変
        @event_cond = nil # 不要

        parse_service_link(event_hash, services_hash)
    end

    #@param [Hash] オーバーレイ情報
    #@return [Proc] チャネル設定更新処理ブロック
    #@note イベント条件判定不要
    #
    def update_state(overlay_info)
        @channel_settings.each do |channel_setting|
            channel_setting.activate()
        end
    end
end

