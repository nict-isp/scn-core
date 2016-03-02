#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require 'singleton'

require_relative './processing/trigger'
require_relative '../utility/message'

#= Event Management class
#
#@author NICT
#
class EventManager
    include Singleton
    include Message

    attr_reader :triggers

    def initialize
        log_trace()
        @triggers = {}
        @overlays = {}
    end

    # Initial setting
    #
    #@param [Integer] interval  The operation period of the event monitoring
    #
    def setup(interval)
        @interval = interval

        supervise()
    end

    # From state monitoring information, to generate and update the intermediate processing of state monitoring
    #
    #@param [String] overlay_id  Overlay ID
    #@param [Hash] app_request   State monitoring information
    #@return [void]
    #
    def set_overlay(overlay_id, overlay)
        log_trace(overlay_id, overlay)
        @overlays[overlay_id] = overlay

        if overlay.nil?
            @triggers[overlay_id] = nil
        else
            trigger = @triggers[overlay_id]
            if trigger.nil?
                @triggers[overlay_id] = Events.new(overlay.trigger)
            else
                trigger.update_request(overlay.trigger)
            end
        end
        log_debug {"#{@triggers}"}
    end

    # To execute the state monitoring
    #
    #@param [Array<Hash>] datas  Received data
    #@return [Array<Hash>] Received data it execute the reception process
    #
    def observe(overlay_id, channel_name, datas)
        log_trace(overlay_id, channel_name, datas)
        trigger = @triggers[overlay_id]
        unless trigger.nil?
            if M2MFormat.formatted?(datas)
                data_list = []
                datas.each do |data|
                    data_list = data_list + M2MFormat.get_values(data)
                end
            else
                data_list = data
            end
            trigger.observe(channel_name, data_list)
        end
    end

    private

    def supervise
        Thread.new do
            loop do
                log_trace
                begin
                    @triggers.each do |id, events|
                        overlay = @overlays[id]
                        unless overlay.nil?
                            channels = overlay.get_current_channels()
                            log_trace(channels)
                            events = events.get_fire_event(channels, @interval)
                            log_trace(overlay, events)
                            next if events.empty?

                            send_propagate([overlay.supervisor], PROPAGATE_DSN_EXECUTOR, "update_overlay", [id, events])
                        end
                    end
                rescue
                    log_error("supervise error.", $!)
                end
                sleep @interval
            end
        end
    end

    # Delegate instance method to class
    class << self
        extend Forwardable
        def_delegators :instance, *EventManager.instance_methods(false)
    end
end
