# -*- coding: utf-8 -*-
require_relative '../compile/dsn_define'

#= Channel request class
# To retain the information at the time of channel generation and change.
#
#@author NICT
#
class ChannelSettings
    include DSN

    #@return [String]  Overlay ID
    attr_reader :overlay
    #@return [String]  Channel ID
    attr_accessor :id
    #@return [Hash]    Application request
    attr_accessor :app_req

    #@param [String] overlay  Overlay ID
    #@param [Hash]   scratch  Sender channel request
    #@param [Hash]   channel  Receiver channel request
    #@param [Hash]   app_req  Intermediate processing request
    #@param [String] block    DNS block name
    #
    def initialize(overlay, scratch, channel, app_req, block)
        @overlay      = overlay
        @id           = nil
        @scratch      = scratch
        @channel      = channel
        @app_req      = app_req
        @log_id       = app_req["id"]
        @block        = block
        @needs_update = false
    end

    # To activate the channel
    #
    #@retun [void]
    #
    def activate()
        if @id.nil?
            @id = Supervisor.create_channel(@overlay, to_request())
        else
            if @needs_update
                Supervisor.update_channel(@id, to_request())
            end
            Supervisor.activate_channel(@id)
        end
        @needs_update = false
    end

    # To inactivates the channel
    #
    #@retun [void]
    #
    def inactivate()
        if @id.nil?
            # do nothing.
        else
            Supervisor.inactivate_channel(@id)
        end
    end

    # To delete a channel
    #
    #@retun [void]
    #
    def delete()
        if @id.nil?
            # do nothing.
        else
            Supervisor.delete_channel(@id)
        end
    end

    # To update the channel
    #
    def update(scratch, channel, app_req)
        if (@scratch != scratch) || (@channel != channel) || (@app_req != app_req)
            @scratch      = scratch
            @channel      = channel
            @app_req      = app_req
            @needs_update = true
        end
    end

    private

    def to_request()
        return {
            "id" => @log_id,
            "block" => @block,
            "scratch" => @scratch,
            "channel" => @channel,
            "app_req" => @app_req,
        }
    end
end

#= Service information class
# To retain the service information.
#
#@author NICT
#
class ServiceInfo
    #@return [String]  Scratch or channel name
    attr_accessor   :name
    #@return [Hash]    Service query
    attr_accessor   :query
    #@return [Integer] Multi number
    attr_accessor   :multi

    #@param [String] name  Scratch or channel name
    #@param [Hash] hash DSN description service definition
    #
    def initialize(name, hash)
        @name  = name
        @query = ServiceHash.query(name, hash)
        @multi = ServiceHash.multi(name, hash)
    end

    #@see Object#==
    def ==(o)
        return @name == o.name && @query == o.query && @multi == o.multi
    end
end

#= Channel information class
#
#@author NICT
#
class ServiceHash
    include DSN

    #@param [String] name  Scratch or channel name
    #@param [Hash]   hash  DSN description service definition
    #@return [Hash] Service query
    #
    def self.query(name, hash)

        query = hash[name].nil?() ? nil : hash[name].select{ |k, v| k != KEY_MULTI }
        return query
    end

    #@param [String] name  Scratch or channel name
    #@param [Hash]   hash  DSN description service definition
    #@return [Integer] Service number of parallel
    #
    def self.multi(name, hash)
        return hash[name][KEY_MULTI][0].to_i
    end
end

