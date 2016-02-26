# -*- coding: utf-8 -*-
require_relative '../compile/dsn_define'
require_relative './channel_settings'

#= Composite channel request class
# The channel request from the DNS, decomposed into a plurality of channels, to generate and change.
#
#@author NICT
#
class ComplexChannelSettings
    include DSN

    #@return [ServiceInfo] Source service
    attr_reader   :src
    #@return [ServiceInfo] Destination service
    attr_reader   :dst
    #@return [Hash] Application request
    attr_accessor :app_req

    #@param [Hash]   link_hash      Transfer definition of DSN description
    #@param [Hash]   channels_hash  Channel definition of DSN description
    #@param [String] block          DSN block name
    #
    def initialize(overlay, link_hash, channels_hash, block)
        @overlay      = overlay
        @block        = block
        @paths        = {}
        @active_paths = []

        update(link_hash, channels_hash)
    end

    #@see Object#==
    def ==(o)
        @src == o.src && @dst == o.dst && @app_req == o.app_req
    end

    #@param [ChannelSettings] o  ChannelSettings object
    #@return [True]  Setting of send and receive destination is same.
    #@return [False] Setting of send and receive destination is not same.
    #
    def same_channel?(o)
        @src == o.src && @dst == o.dst
    end

    # To update the channel request
    #
    #@param [Hash] link_hash      Transfer definition of DSN description
    #@param [Hash] channels_hash  Channel definition of DSN description
    #@return [void]
    #
    def update(link_hash, channels_hash)
        @app_req     = link_hash[KEY_APP_REQUEST]
        @log_id      = @app_req["id"]
        
        scratch_name = @app_req["scratch"]["name"]
        channel_name = @app_req["channel"]["name"]
        @src         = channels_hash[scratch_name]
        @dst         = channels_hash[channel_name]
        @scratch = {
            "name"  => scratch_name,
            "query" => @src.query,
            "multi" => @src.multi,
        }
        @channel = {
            "name"  => channel_name,
            "query" => @dst.query,
            "multi" => @dst.multi,
        }
    end
    
    # To decompose and generates channel request to the actual channel.
    #
    #@param [Hash<String, MergeSettings>] merge_settings  Merge request
    #@return [void]
    #
    def update_path(merge_settings)
        active_paths = []

        scratch     = @scratch.dup
        channel     = @channel.dup
        select      = @app_req["scratch"]["select"].dup
        processings = @app_req["processing"].dup

        # If there is a aggregate function, to divide the path before and after the function.
        aggregate = processings.index{|processing| processing.has_key?("aggregate")}
        if aggregate
            # Intermediate processing of the path first half.
            if aggregate > 0
                aggregate_processing = processings.slice(0..aggregate - 1)
            else
                aggregate_processing = []
            end
            # aggregate service request
            aggregate_req = processings[aggregate]["aggregate"]
            aggregate_req["type"] = "aggregate"
            aggregate_channel     = {
                "inner" => aggregate_req,
                "name"  => "#{scratch["name"]}#aggregate",
                "multi" => 1,
            }
            # To generate a path to the aggregate service.
            active_paths << create_settings("aggregate", scratch, aggregate_channel, select, aggregate_processing, @block)

            # To set the rest of the path.
            select      = []
            processings = processings.slice(aggregate + 1..-1)
            scratch     = aggregate_channel
        end
    
        # If it sets to dst of merge function, and generates a path through the merge.
        merge_pair = merge_settings.find{|key, merge| merge.dst == @channel["name"] }
        if merge_pair.nil?
            # Normal path
            active_paths << create_settings("normal", scratch, channel, select, processings, @block)
        else
            merge = merge_pair[1]
            # To generate a path for the input to the merge and for the output from the merge.
            active_paths << create_settings("merge_in", scratch, merge.channel, select, processings, @block)
            active_paths << create_settings("merge_out", merge.channel, channel, merge.app_req["select"], merge.app_req["processing"], merge.block)
        end

        @active_paths = active_paths
    end

    # To activate the channel.
    #
    #@param [Hash<String, MergeSettings>] merge_settings  Merge request
    #@return [void]
    #
    def activate(merge_settings)
        update_path(merge_settings)

        @paths.values.each do |path|
            if @active_paths.include?(path)
                path.activate()
            else
                path.inactivate()
            end
        end
    end

    # To inactivates the channel.
    #
    #@retun [void]
    #
    def inactivate()
        @paths.values.each do |path|
            path.inactivate()
        end
    end

    # To delete the channel.
    #
    #@retun [void]
    #
    def delete()
        @paths.values.each do |path|
            path.delete()
        end
    end

    private 

    # To generate a channel request. If already generated to update the channel request.
    #
    def create_settings(key, scratch, channel, select, processings, block)
        app_req = deep_copy(@app_req)
        app_req["scratch"]["select"] = select
        app_req["processing"]        = processings

        path = @paths[key]
        if path.nil?
            log_debug{"key = #{key}, processings = #{processings}"}
            path = ChannelSettings.new(@overlay, scratch, channel, app_req, block)
            @paths[key] = path
        else
            path.update(scratch, channel, app_req)
        end
        return path
    end
end

