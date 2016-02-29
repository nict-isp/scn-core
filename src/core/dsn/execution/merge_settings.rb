# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative '../compile/dsn_define'
require_relative './channel_settings'

#= Merge request class
# To convert the merge request from the DNS to the channel, to generate and change.
#
#@author NICT
#
class MergeSettings
    include DSN

    #@return [Hash]          Merge channel request
    attr_reader   :channel
    #@return [String]        Source channel
    attr_reader   :dst
    #@return [Array<String>] Destination channels
    attr_reader   :srcs
    #@return [Boolean]       Merge is active
    attr_reader   :active
    #@return [String]        Merge block name
    attr_reader   :block
    #@return [String]        Merge application request
    attr_reader   :app_req

    #@param [String] overlay        Overlay ID
    #@param [Hash]   merge_hash     DSN description merge definition
    #@param [Hash]   channels_hash  DSN description channel definition
    #
    def initialize(overlay, merge_hash, service_hash)
        @overlay  = overlay
        @paths    = {}
        @active   = true

        update(merge_hash, service_hash)
    end

    # To update the merge request
    #
    #@param [Hash] merge_hash     DSN description merge definition
    #@param [Hash] channels_hash  DSN description channel definition
    #@return [void]
    #
    def update(merge_hash, service_hash)
        @dst     = merge_hash[KEY_MERGE_DST]
        @srcs    = merge_hash[KEY_MERGE_SRC]
        @block   = "#{@dst}##{merge_hash[KEY_TYPE]}"
        @app_req = merge_hash[KEY_APP_REQUEST]
        @channel = {
            "inner" => merge_hash,
            "name"  => @block,
            "multi" => 1,
        }
        @srcs.each do |src|
            service = service_hash[src]
            scratch = {
                "name"    => src,
                "channel" => "#{@overlay}##{src}",
                "query"   => service.query,
                "multi"   => service.multi,
            }
            create_settings(src, scratch, @channel)
        end
    end

    # To activate the channel
    #
    #@return [void]
    #
    def activate()
        @active = true
        @paths.each do |src, path|
            if @srcs.include?(src)
                path.activate()
            else
                path.inactivate()
            end
        end
    end

    # To inactivates the channel
    #
    #@retun [void]
    #
    def inactivate()
        @active = false
        @paths.values.each do |path|
            path.inactivate()
        end
    end

    private 

    # To generate a channel request. If already generated to update the channel request.
    #
    def create_settings(src, scratch, channel)
        app_req = {
            "channel" => {
                "name"   => channel["name"],
                "select" => [],
                "meta"   => {},
            },
            "scratch" => {
                "name"    => scratch["name"],
                "select"  => [],
                "meta"    => {},
            },
            "processing" => [],
            "qos"        => {},
        }
        path = @paths[src]
        if path.nil?
            @paths[src] = ChannelSettings.new(@overlay, scratch, channel, app_req, @block)
        else
            path.update(scratch, channel, app_req)
        end
    end
end

