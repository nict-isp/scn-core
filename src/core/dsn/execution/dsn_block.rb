# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative '../../utils'
require_relative '../compile/dsn_define'
require_relative '../compile/conditions'
require_relative '../../translator/supervisor'
require_relative './complex_channel_settings'

#= Channel configuration block class
#  To retain the setting of event_condition do block of DSN description.
#
#@author NICT
#
class DSNEventBlock
    include DSN

    #@return [String]  Overlay ID
    attr_reader   :overlay
    #@return [Hash]    Condition that the event is established
    attr_reader   :event_cond
    #@return [True]    State that the event has been established
    #@return [False]   State that the event has not been established
    attr_reader   :event_state
    #@return [Array]   Channel set list at the time of establishment of an event
    attr_reader   :channel_settings
    #@return [Array]   State monitoring at the time of establishment of an event
    attr_reader   :trigger

    #@param [String] overlay        Overlay ID
    #@param [Hash]   event_hash     DSN description event condition block
    #@param [Hash]   channels_hash  Service block(Pass to ChannelSettings)
    #
    def initialize(overlay, event_hash, channels_hash)
        log_debug{"event_hash = #{event_hash}"}
        @overlay     = overlay
        @event_state = false
        @event_cond  = event_hash[KEY_CONDITIONS]
        @trigger     = event_hash[KEY_TRIGGER]

        @block = compile_conditions(@event_cond)
        parse_service_link(event_hash, channels_hash)
    end

    #@param [Hash] trigger_hash  Trigger setting of the entire DSN description
    #@return [Hash] Trigger settings updated
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

    #@param [Hash] merge_hash  Merge settings for the entire DSN description
    #@return [Hash] Merge settings updated
    #
    def merge_merges(merge_hash)
        if @event_state == true
            @merges.each do |merge|
                dst = merge[KEY_MERGE_DST]
                if merge_hash.has_key?(dst)
                    # If the merge that specify the same dst is more than one.
                    dst_merge = merge_hash[dst]
                    # Combine all of the source.
                    dst_merge[KEY_MERGE_SRC]  |= merge[KEY_MERGE_SRC]
                    # To apply the delay of minimum.
                    dst_merge[KEY_DELAY] = [dst_merge[KEY_DELAY], merge[KEY_DELAY]].min
                else
                    merge_hash[dst] = merge
                end
            end
        end
        return merge_hash
    end

    #@param [Hash] overlay_info  Overlay information
    #@return [Hash]  State of Block(for logging)
    #
    def update_state(events)
        log_debug{"#{events}"}
        # To make sure that the conditions are satisfied.
        @event_state = Conditions.ok?(@event_cond, events)
    end

    #@param [Hash] event_hash     Event condition block
    #@param [Hash] channels_hash  Service block(Pass to ChannelSettings)
    #
    def modify(event_hash, channels_hash)
        log_debug(){"old_settings = #{@channel_settings}"}
        @merges = event_hash[KEY_MERGES]
        log_debug(){"@merges = #{@merges}"}

        new_settings = []
        old_settings = @channel_settings.dup
        # To add a channel that have been added to @channel_setting.
        event_hash[KEY_SERVICE_LINK].each do |link_hash|
            new_setting = ComplexChannelSettings.new(@overlay, link_hash, channels_hash, @block)

            # Consideration of a case in which the same elements there is more than one, to use the delete_at.
            old_index = old_settings.index(new_setting)
            if old_index.nil?
                old_index = old_settings.index{|setting| setting.same_channel?(new_setting) }
                if old_index.nil?
                    # New Settings
                    new_settings << new_setting
                else
                    # Match of only src and dst
                    old_setting = old_settings.delete_at(old_index)
                    old_setting.update(link_hash, channels_hash)
                    new_settings << old_setting
                end
            else
                # Perfect matching(Operation unnecessary)
                new_settings << old_settings.delete_at(old_index)
            end
        end
        @channel_settings = new_settings
        # To delete the unwanted channels.
        old_settings.each {|setting| setting.delete}

        log_debug(){"new_settings = #{@channel_settings}"}
    end

    # To update the channel request of the block.
    #
    #@param [Hash<String, MergeSetting>] merge_settings  Merge request
    #@retrun [void]
    #
    def update(merge_settings)
        if @event_state == true
            @channel_settings.each do |channel_setting|
                channel_setting.activate(merge_settings)
            end
        else
            @channel_settings.each do |channel_setting|
                channel_setting.inactivate()
            end
        end
    end

    private

    #@param [Hash] event_hash     Event condition block
    #@param [Hash] channels_hash  Service block(Pass to ChannelSettings)
    #
    def parse_service_link(event_hash, channels_hash)
        @merges = event_hash[KEY_MERGES]
        log_debug(){"@merges = #{@merges}"}

        @channel_settings = []
        event_hash[KEY_SERVICE_LINK].each do |link_hash|
            begin
                @channel_settings << ComplexChannelSettings.new(@overlay, link_hash, channels_hash, @block)
            rescue
                log_error("", $!)
            end
        end
    end

    #@param [String] key     Key
    #@param [Array]  values  Values
    #@return [String] String of condition that the event is established
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

    #@param [Hash] conditions   Condition that the event is established
    #@return [String] String of condition that the event is established
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
            return result   # Hash of the conditional expression has only one element.
        end
    end
end

#= Channel constantly setting block class
#  To retain the setting of bloom do block of DSN description.
#
class DSNConstantBlock < DSNEventBlock

    #@param [String] id             Overlay ID
    #@param [Hash]   event_hash     DSN description event condition block
    #@param [Hash]   channels_hash  Service block(Pass to ChannelSettings)
    #
    def initialize(id, event_hash, channels_hash)
        super
        @event_state = true # Immutable
        @event_cond = nil # Unnecessary

        parse_service_link(event_hash, channels_hash)
    end

    #@param [Hash] overlay_info  Overlay information
    #@return [Proc] Channel setting update processing block
    #@note Event condition decision unnecessary
    #
    def update_state(overlay_info)
        # nop
    end
end

