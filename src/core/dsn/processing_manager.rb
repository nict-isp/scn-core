#-*- codIng: utf-8 -*-
require 'singleton'

require_relative '../utils'
require_relative './processing/on_node'
require_relative './processing/in_network'
require_relative '../translator/stats'
require_relative '../translator/supervisor'

#= Intermediate processing management class
#
#@author NICT
#
class ProcessingManager
    include Singleton

    def initialize()
        @scratchs    = {}
        @channels    = {}
        @processings = {}
        @services    = {}

        @overlays    = Hash.new {|h, k| h[k] = {
                "paths"    => Hash.new {|h, k| h[k] = {} },
                "services" => Hash.new {|h, k| h[k] = {} },
            }
        }
    end

    # To generate and update an instance of the intermediate processing from the overlay information
    #
    #@param [String] overlay_id  Overlay ID
    #@param [Overlay] overlay    Overlay information
    #@return [void]
    #
    def set_overlay(overlay_id, overlay)
        log_trace(overlay_id, overlay)

        new_paths    = {}
        new_services = {}
        unless overlay.nil?
            overlay.channels.each do |id, channel|
                request = channel.channel_req["app_req"]
                channel.paths.each do |path|
                    new_paths[path.id] = path

                    update_scratch(channel, path, request, overlay_id)
                    update_channel(channel, path, request, overlay_id)
                    update_processings(channel, path, request)
                end
            end

            overlay.services.each do |id, service|
                update_service(id, service)
            end
        end
        
        (@overlays[overlay_id]["paths"].keys - new_paths.keys).each {|path_id| delete_paths(path_id)}
        @overlays[overlay_id]["paths"] = new_paths

        (@overlays[overlay_id]["services"].keys - new_services.keys).each {|service_id| delete_services(service_id)}
        @overlays[overlay_id]["services"] = new_services
    end

    # It performs intermediate processing, and transmits the data.
    #
    #@param [String]      service_id  Service ID
    #@param [Array<Hash>] data        Transmitted data
    #@param [Integer]     data_size   Transmitted data size
    #@param [String]      channel_id  Channel specified at the time of transfer (overlay ID # channel name)
    #@param [Boolean]     sync        When True, the wait for the completion of the transmission (performance evaluation for optional)
    #@return [JSON] The array of the transmitted channels
    #@raise [ArgumentError]  Nonexistent channel ID is specified / data format invalid
    #@raise [Timeout::Error] Request timed out
    #
    def send_data(service_id, data, data_size, channel_id = nil, sync = false)
        log_trace(service_id, data_size, channel_id, sync)
        channels = []
        @scratchs.each do |id, scratch|
            onnode_processing, channel, path, overlay_id = scratch
            next unless path.src_service.id == service_id   # source service does not match
            next unless channel.active                      # channel of non-active
            next if channel.source != channel_id            # channel specified at the time of transfer

            begin
                # During transmission processing
                processed = data
                # In-Network data processing(if any)
                innet_processings = @processings[path.id]
                unless innet_processings.nil?
                    processed = innet_processings.execute(processed)
                end
                # During transmission processing
                processed = onnode_processing.execute(processed)

                if processed.size > 0
                    processed_size = calc_size(processed)
                    path.send(processed, processed_size)
                    channels << channel.id
                else
                    processed_size = 0
                end

                Stats.send_data(path, data_size, processed_size)
                # for ETL Wrokflow Editor
                send_message(overlay_id, channel, data, data_size, processed, processed_size)

            rescue
                log_error("failed to send.", $!)
            end
        end
        return channels
    end

    # Execue intermediate processing, to receive the data.
    #
    #@param [String]      path_id    Logical path ID
    #@param [Array<Hash>] data       Received data
    #@param [Integer]     data_size  Received data size
    #@return [void]
    #
    def receive_data(path_id, data, data_size)
        log_trace(path_id, data_size)

        # In-Network data processing(if any)
        innet_processings = @processings[path_id]
        if innet_processings.nil?
            processed = data
        else
            processed = innet_processings.execute(data)
            if processed.size < 1
                return
            end
        end

        onnode_processing, channel, path, overlay_id = @channels[path_id]
        if (not channel.nil?)
            # Since the destination node, execute the reception during processing
            return unless channel.active    # channel of non-active
            EventManager.observe(overlay_id, channel.channel_req["channel"]["name"], processed)

            processed      = onnode_processing.execute(processed)
            processed_size = calc_size(processed)
            dst_service    = path.dst_service
            inner_service  = @services[dst_service.id]
            if inner_service.nil?
                ApplicationRPCClient.receive_data(processed, processed_size, channel.id, dst_service.port)

                # Transfer of data
                send_data(dst_service.id, processed, processed_size, "#{overlay_id}##{channel.name}")
            else
                inner_service.receive_data(processed, processed_size, channel.id)
            end
            Stats.receive_data(path, processed_size)

        elsif (not path.nil?)
            # Since the relay node, re-transmission to the next flow
            path.send(processed, data_size)
        else
            log_warn("Invalid path id #{path_id}")
        end
    end

    private
    
    def update_scratch(channel, path, request, overlay_id)
        log_trace(channel, path, request)
        src_service = path.src_service
        return unless current_node?(src_service.ip)

        processing, = @scratchs[path.id]
        if processing.nil? 
            processing = OnNodeProcessing.new(src_service, request["scratch"]["select"])
        else
            processing.update_request(request["scratch"]["select"])
        end
        @scratchs[path.id] = [processing, channel, path, overlay_id]
    end

    def update_channel(channel, path, request, overlay_id)
        log_trace(channel, path, request, overlay_id)
        dst_service = path.dst_service
        return unless current_node?(dst_service.ip)

        processing, = @channels[path.id]
        if processing.nil?
            processing = OnNodeProcessing.new(dst_service, request["channel"]["select"])
        else
            processing.update_request(request["channel"]["select"])
        end
        @channels[path.id] = [processing, channel, path, overlay_id]
    end

    def update_processings(channel, path, request)
        log_trace(channel, path, request)
        path.processings.each do |ip, processings|
            next unless current_node?(ip)

            processing = @processings[path.id]
            if processing.nil?
                processing = InNetoworkDataProcessing.new(processings)
            else
                processing.update_request(processings)
            end
            @processings[path.id] = processing
        end
    end

    def update_service(id, service)
        return unless current_node?(service.ip)

        cache = @services[id]
        if cache.nil?
            @services[id] = service
            service.start()
        else
            cache.update(service.info)
        end
    end

    def delete_paths(path_id)
        @scratchs.delete(path_id)
        @channels.delete(path_id)
        @processings.delete(path_id)
    end

    def delete_service(id)
        service = @services.delete(id) 
        service.stop()
    end

    def send_message(overlay_id, channel, data, data_size, processed, processed_size)
        message = {
            "overlay_id" => overlay_id,
            "transfers"  => {
                channel.id => {
                    "input_tuples"  => get_values(data).size,
                    "input_size"    => data_size,
                    "output_tuples" => get_values(processed).size,
                    "output_size"   => processed_size,
                }
            }
        }
        Supervisor.send_message(overlay_id, message)
    end

    def get_values(data)
        if M2MFormat.formatted?(data)
            return M2MFormat.get_values(data)
        else
            return data
        end
    end

    # Delegate instance method to class
    class << self
        extend Forwardable
        def_delegators :instance, *ProcessingManager.instance_methods(false)
    end
end

