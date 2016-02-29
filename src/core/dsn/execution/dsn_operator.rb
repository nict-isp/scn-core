# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require 'json'

require_relative '../../utils'
require_relative '../../utility/collector'
require_relative '../compile/dsn_define'
require_relative './dsn_block'
require_relative './complex_channel_settings'
require_relative './merge_settings'

#= Overlay state management class
# To manage the overlay state.
#
class DSNOperator
    include DSN

    #@return [String]   Overlay ID
    attr_reader   :id
    #@return [String]   Overlay name
    attr_reader   :overlay_name
    #@return [Array]    Channel setting definition block (bloom do＋event do)
    attr_reader   :blocks

    #@param [String] id        Overlay ID
    #@param [Hash]   dsn_hash  DSN description (Intermediate code)
    #
    def initialize(id, dsn_hash)
        log_trace(id, dsn_hash)
        @id           = id
        @dsn_hash     = dsn_hash
        @overlay_name = dsn_hash[KEY_OVERLAY]
        @event_state  = {}
        @merges       = {}
        parse_blocks(dsn_hash)
    end

    #@return [String] Response message
    #@raise [ApplicationError] An error has occurred in the API call of SCN middleware
    #
    def create_overlay()
        update_trigger()
        return update_overlay({})
    end

    #@param [Hash] event_state  Event state
    #@return [String] Response message
    #@raise [ApplicationError] An error has occurred in the API call of SCN middleware
    #
    def update_overlay(event_state)
        log_time()
        log_debug{"input  #{event_state}"}

        log_debug{"before #{@event_state}"}
        @event_state.merge!(event_state)
        log_debug{"after  #{@event_state}"}

        log_time()
        update()
    end

    #@param [Hash] dsn_hash  DSN description (intermediate code)
    #@return [void]
    #@raise [ApplicationError] An error has occurred in the API call of SCN middleware
    #
    def modify_overlay(dsn_hash)
        log_time()

        @dsn_hash      = dsn_hash
        services_hash  = dsn_hash[KEY_SERVICES]
        @channels_hash = create_channels_hash(dsn_hash, services_hash)
        sl_empty_hash  = { KEY_SERVICE_LINK => []}

        log_debug(){"@blocks = #{@blocks}"}

        # To remove a block that has been removed from @blocks.
        deleted_blocks = []
        @blocks.each do |block|
            if not block.event_cond.nil?
                if not dsn_hash[KEY_EVENTS].any? { |event_hash| block.event_cond == event_hash[KEY_CONDITIONS] }
                    deleted_blocks << block
                    # To remove a channel in the block by giving an empty hash.
                    block.modify({KEY_SERVICE_LINK => []}, {KEY_SERVICES => nil})
                end
            end
        end
        @blocks = @blocks - deleted_blocks

        # To update the block that has been changed.
        @blocks.each do |block|
            if block.event_cond.nil?
                block.modify(dsn_hash, @channels_hash)
            else
                event_hash = dsn_hash[KEY_EVENTS].find { |event_hash| block.event_cond == event_hash[KEY_CONDITIONS] }
                block.modify(event_hash, @channels_hash)
            end
        end

        # To add a block that has been added to @blocks.
        dsn_hash[KEY_EVENTS].each do |event_hash|
            if not @blocks.any? { |sls_block| sls_block.event_cond == event_hash[KEY_CONDITIONS] }
                @blocks << DSNEventBlock.new(@id, event_hash, @channels_hash)
            end
        end

        log_debug(){"@blocks = #{@blocks}"}

        update()
    end

    private

    # To convert the service definition from the DSN description in the form of a scratch name and the channel name to the key.
    #
    def create_channels_hash(dsn_hash, services_hash)
        channels_hash = {}
        block_hash_array = [dsn_hash]
        dsn_hash[KEY_EVENTS].each do |event_hash|
            block_hash_array << event_hash
        end
        block_hash_array.each do |block_hash|
            block_hash[KEY_SERVICE_LINK].each do |link_hash|
                app_req = link_hash[KEY_APP_REQUEST]
                channels_hash[app_req["scratch"]["name"]] = ServiceInfo.new(link_hash[KEY_TRANS_SRC], services_hash)
                channels_hash[app_req["channel"]["name"]] = ServiceInfo.new(link_hash[KEY_TRANS_DST], services_hash)
            end
        end
        return channels_hash
    end

    #@raise [ArgumentError] DSN description mismatch
    #@note Errors detected here are structural mismatch of the intermediate code.
    #      Inconsistency of definition(Service does not exist, there is no trigger
    #      corresponding to the event block, etc.) is error detection at the time of API execution.
    #
    def parse_blocks(dsn_hash)
        # state do block
        services_hash = dsn_hash[KEY_SERVICES]
        # bloom do block
        @channels_hash = create_channels_hash(dsn_hash, services_hash)
        @blocks = []
        @blocks << DSNConstantBlock.new(@id, dsn_hash, @channels_hash)
        # events do block
        dsn_hash[KEY_EVENTS].each do |event_hash|
            @blocks << DSNEventBlock.new(@id, event_hash, @channels_hash)
        end
    end

    def update
        log_time()

        # To update the status of the block on the basis of the event state.
        @blocks.each do |block|
            block.update_state(@event_state)
        end

        # To update the settings of a effective merge.
        update_merges()
        active_merges = @merges.select{|k, v| v.active}
        @blocks.each do |block|
            # To update the status of the path in the block.
            block.update(active_merges)
        end

        # To update the configuration of effective trigger.
        update_trigger()

        log_time()
    end

    # To generate and change the merge request.
    # Since the merge request affects the whole DSN, it is generated here(Outside of the block).
    #
    def update_merges()
        merges = {}
        @blocks.each do |block|
            merges = block.merge_merges(merges)
        end
        log_debug{"merges = #{merges}"}

        # To generate and change the merge request each dst.
        merges.each do |channel, merge|
            merge_setting =  @merges[channel]
            begin
                if merge_setting.nil?
                    merge_setting = MergeSettings.new(@id, merge, @channels_hash)
                    @merges[channel] = merge_setting
                else
                    merge_setting.update(merge, @channels_hash)
                end
            rescue
                log_error("", $!)
            end
        end
       
        active_channels = merges.keys()
        @merges.each do |channel, merge|
            begin
                if active_channels.include?(channel)
                    merge.activate()
                else
                    merge.inactivate()
                end
            rescue
                log_error("", $!)
            end
        end 

        log_debug{"@merges = #{@merges}"}
    end

    def update_trigger()
        # To set create an empty trigger for the all events.
        trigger = {}
        @blocks.each do |block|
            trigger = block.merge_trigger(trigger)
        end

        trigger.each do |event_name, hash|
            if @event_state[event_name].nil?
                @event_state[event_name] = false
                hash["state"] = false
            else
                hash["state"] = @event_state[event_name]
            end
        end

        Supervisor.set_trigger(@id, trigger)
    end
end
