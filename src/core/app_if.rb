# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require 'json'
require 'msgpack/rpc'
require 'singleton'
require_relative './utils'
require_relative './utility/validator'

#= Class that manages the RPC of the application
#
# It manages the port and IP address for the RPC, to generate an RPC server and client.
#
#@author NICT
#
class ApplicationRPC

    # Initial setting
    #
    #@param [Integer] rpc_rx_port    Port for RPC reception
    #@param [Integer] rpc_ip_address IP address for RPC send
    #@return [void]
    #
    def initialize(rpc_rx_port, rpc_ip_address)
        log_trace(rpc_rx_port, rpc_ip_address)
        @rpc_rx_port    = rpc_rx_port
        @rpc_ip_address = rpc_ip_address

        ApplicationRPCClient.setup(@rpc_ip_address)
    end

    # To generate the RPC server and client for the application.
    #
    #@return [void]
    #
    def start()
        log_trace()
        Thread.new do
            begin
                log_debug() {"RPC receive server start. RX port = #{@rpc_rx_port}"}
                @rpc_server = MessagePack::RPC::Server.new
                @rpc_server.listen("0.0.0.0", @rpc_rx_port, ApplicationRPCServer.instance)
                @rpc_server.run

            ensure
                log_error() {"RPC receive server stop."}
            end
        end
    end
end

#= RPC server class for the API of the Application.
#
# To define the methods that are called via RPC from application.
#
#@author NICT
#
class ApplicationRPCServer
    include Singleton

    # API for the service to join
    #
    #@param [String]  service_name   Service name
    #@param [Hash]    service_info   Service information
    #@param [Integer] port           Receiving port number of the service
    #@return [String] service ID
    #@raise [ArgumentError] The format of the service information is incorrect.
    #
    def join_service(service_name, service_info, port)
        log_trace(service_name, service_info, port)
        log_time()
        Validator.service_info(service_info)
        service_id = Supervisor.join_service(service_name, service_info, port)

        log_info("service name(=#{service_name}) was joined successfully. (service ID =#{service_id})")

        log_time()
        return service_id

    rescue Exception
        log_error("service name(=#{service_name}) failed to join.", $!)
        raise ApplicationError, $!
    end

    # API for the service information to change
    #
    #@param [String] service_id    Service ID
    #@param [Hash]   service_info  Service information
    #@return [void]
    #@raise [ArgumentError]  Non-existent service ID is specified. / The format of the service information is incorrect.
    #@raise [Timeout::Error] Time-out has occurred in the communication between the nodes.
    #
    def update_service(service_id, service_info)
        log_trace(service_id, service_info)
        log_time()        
        Validator.service_info(service_info)

        Supervisor.update_service(service_id, service_info)

        log_info("service ID(=#{service_id}) was updated successfully. (info = #{service_info})")
        log_time()

    rescue Exception
        log_error("service ID(=#{service_id}) failed to update.", $!)
        raise ApplicationError, $!
    end

    # API for the service to leave
    #
    #@param [String] service_id  Service ID
    #@return [void]
    #@raise [ArgumentError]  Non-existent service ID is specified.
    #@raise [Timeout::Error] Time-out has occurred in the communication between the nodes.
    #
    def leave_service(service_id)
        log_trace(service_id)
        log_time()
        Supervisor.leave_service(service_id)

        log_info("service ID(=#{service_id}) was leaved successfully.")
        log_time()

    rescue Exception
        log_error("service ID(=#{service_id}) failed to leave.", $!)
        raise ApplicationError, $!
    end

    # API for sending data
    #
    #@param [String]      service_id  Service ID
    #@param [String/Hash] data        Transmission data
    #@param [Integer]     data_size   Transmission data size
    #@param [String]      channel_id  Channel ID
    #@param [Boolean]     sync        When True, the wait for the completion of the transmission
    #@return [JSON] The array of the transmitted channels
    #@raise [ArgumentError]  Non-existent service ID is specified. / The format of the data is incorrect.
    #@raise [Timeout::Error] Request timed out.
    #
    def send_data(service_id, data, data_size, channel_id, sync)
        log_trace(service_id, data_size, channel_id, sync)
        log_time()
        corrected_data = correction_data(data)
        channel_id_list = Supervisor.send_data(service_id, corrected_data, data_size, channel_id, sync)
        log_time()

        json = JSON.dump(channel_id_list)
        log_debug() {"channel ID list = \"#{json}\""}

        log_time()
        return json

    rescue Exception
        log_error("data(#{data_size} bytes) failed to send.", $!)
        raise ApplicationError, $!
    end

    # API for the DSN description to generate
    # From Event Data Model, to generate a DSN description.
    #
    #@param [String] table_name        Table name
    #@param [Hash]   event_data_model  Event Data Model
    #@retrun [String] Generated DSN description
    #@raise [ArgumentError] The format of the Event Data Model is incorrect.
    #
    def create_dsn(table_name, event_data_model)
        log_trace(table_name, event_data_model)
        log_time()
        dsn_desc, overlay_name = DSNCreator.create_dsn(table_name, event_data_model)
        log_time()
        log_debug() {"overlay_name = #{overlay_name}, dsn desc = #{dsn_desc}"}

        return overlay_name, dsn_desc

    rescue Exception
        log_error("failed to create DSN.", $!)
        raise ApplicationError, $!
    end

    # API for the overlay to generate
    #
    #@param [String]  overlay_name  Overlay name
    #@param [String]  dsn_desc      DSN description
    #@param [Integer] port          Message reception port
    #@retrun [String] Overlay ID
    #
    def create_overlay(overlay_name, dsn_desc, port)
        log_trace(overlay_name, dsn_desc, port)
        log_time()
        overlay_id = Supervisor.create_overlay(overlay_name, port)
        DSNExecutor.add_dsn(overlay_id, dsn_desc)

        log_debug() {"overlay(#{overlay_name}) has been created successfully. (id = #{overlay_id})"}
        log_time()

        return overlay_id

    rescue Exception
        log_error("failed to create overlay.", $!)
        Supervisor.delete_overlay(overlay_id)
        raise ApplicationError, $!
    end

    # API for the overlay to delete
    #
    #@param [String] overlay_id  Overlay ID
    #
    def delete_overlay(overlay_id)
        log_trace(overlay_id)
        log_time()
        DSNExecutor.delete_dsn(overlay_id)
        Supervisor.delete_overlay(overlay_id)

        log_debug() {"overlay(#{overlay_id}) has been deleted successfully."}
        log_time()

    rescue Exception
        log_error("failed to delete overlay.", $!)
        raise ApplicationError, $!
    end

    # API for the overlay to modify
    #
    #@param [String] overlay_name  Overlay name
    #@param [String] overlay_id    Overlay ID
    #@param [String] dsn_desc      DSN description
    #
    def modify_overlay(overlay_name, overlay_id, dsn_desc)
        log_trace(overlay_name, overlay_id, dsn_desc)
        log_time()
        DSNExecutor.modify_dsn(overlay_id, dsn_desc)

        log_debug() {"overlay(#{overlay_id}) has been modified successfully."}
        log_time()

    rescue Exception
        log_error("failed to modify overlay.", $!)
        raise ApplicationError, $!
    end

    # API for get the channel
    #
    #@param [String] channel_id  Channel ID
    #@return [JSON] Channel
    #
    def get_channel(channel_id)
        log_trace(channel_id)
        log_time()
        channel = Supervisor.get_channel(channel_id)
        if channel.nil?
            raise InvalidIDError, "channel not found"
        end

        app_req = channel.channel_req["app_req"]
        channel_info = {
            "id"      => app_req["id"],
            "channel" => app_req["channel"]["meta"],
            "scratch" => app_req["scratch"]["meta"],
            "qos"     => app_req["qos"],
        }
        json = JSON.dump(channel_info)
        log_debug() {"channel = \"#{json}\""}
        log_time()

        return json

    rescue Exception
        log_error("get channel failed.", $!)
        raise ApplicationError, $!
    end

    # API for the service to search
    #
    #@param [Hash]    query    Search conditions of service
    #@param [Integer] require  Number of requests
    #@return [JSON] Array of the hit service information
    #
    def discovery_service(query, require=nil)
        log_trace(query, require)
        log_time()

        log_debug() {"discovery = \"#{query}\", require = \"#{require}\""}
        services = Supervisor.discovery_service(query, require) 
        services_info = services.map{|service| service.to_info()}
        json = JSON.dump(services_info)   
    
        log_debug() {"discovery result = \"#{json}\""}
        log_time()

        return json

    rescue Exception
        log_error("discovery service failed.", $!)
        raise ApplicationError, $!
    end

    private

    def correction_data(data)
        if data.instance_of? String
            begin
                corrected_data = JSON.load(data)
            rescue
                raise ArgumentError, "data format is invalid. data is not in JSON format."
            end

        elsif data.instance_of? Array
            corrected_data = data

        elsif data.instance_of? Hash
            corrected_data = data

        else
            raise ArgumentError, "data format is invalid. data type = #{data.class}"
        end

        return corrected_data
    end

    # Delegate instance method to the class.
    class << self
        extend Forwardable
        def_delegators :instance, *ApplicationRPCServer.instance_methods(false)
    end
end

#= RPC client class for the API of the Application
#
# To define the method of the Application to call via RPC.
#
#@author NICT
#
class ApplicationRPCClient
    include Singleton

    def initialize()
        @message_log_dir = ""
    end

    # Initial setting
    #
    #@param [String] rpc_ip_address  IP address for RPC transmission
    #@return [void]
    #
    def setup(rpc_ip_address)
        log_trace(rpc_ip_address)
        @rpc_ip_address = rpc_ip_address
    end

    # API for receiving data
    #
    #@param [String/Hash] data         Received data
    #@param [Integer]     data_size    Received data size
    #@param [String]      channel_id   Channel ID
    #@param [Integer]     rpc_tx_port  Transmit port for the RPC
    #@return [void]
    #
    def receive_data(data, data_size, channel_id, rpc_tx_port)
        log_trace(data, data_size, channel_id, rpc_tx_port)
        log_time()
        log_info("data(#{data_size} bytes) received. (channel ID = #{channel_id})")

        log_time()
        client = MessagePack::RPC::Client.new(@rpc_ip_address, rpc_tx_port)
        client.timeout = 60
        client.call(:receive_data, data, data_size, channel_id)
        log_time()
        client.close

        log_time()
    rescue Exception
        log_error("receive_data() RPC connection error. RPC tx port = #{rpc_tx_port}", $!)
    end

    # API for receiving message
    #
    #@param [String]  overlay_id   Overlay ID, which has received the message
    #@param [String]  message      Message
    #@param [Integer] rpc_tx_port  Transmit port for the RPC
    #@return [void]
    #
    def receive_message(overlay_id, message, rpc_tx_port)
        log_trace(overlay_id, message, rpc_tx_port)
        log_time()        
        log_info("message received. (overlay id = #{overlay_id})")

        if rpc_tx_port.nil?
            DSNAutoExecutor.log_auto_execute_message(overlay_id, message)
        else
            log_time()
            client = MessagePack::RPC::Client.new(@rpc_ip_address, rpc_tx_port)
            client.timeout = 60
            client.call(:receive_message, overlay_id, message)
            log_time()
            client.close
        end

    rescue Exception
        log_error("receive_message() RPC connection error. RPC tx port = #{rpc_tx_port}", $!)
    end

    # Delegate instance method to the class.
    class << self
        extend Forwardable
        def_delegators :instance, *ApplicationRPCClient.instance_methods(false)
    end
end
