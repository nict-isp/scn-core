# -*- coding: utf-8 -*-
require_relative './utils'
require_relative './utility/collector'
require_relative './translator/supervisor'
require_relative './translator/stats'
require_relative './ncps/ncps'
require_relative './app_if'
require_relative './dsn/dsn_executor'
require_relative './dsn/dsn_creator'
require_relative './dsn/event_manager'
require_relative './dsn/processing_manager'

#= The main class of SCN middleware
# The body of process for SCN middleware.
#
#@author NICT
#
class SCNManager

    def initialize()
        @rpc_initial_rx_port = $config[:rpc_initial_rx_port]
    end

    # It performs the participation notification SCN middleware, performs various initialization settings.
    #
    #@param [String]  ip          IP address of the local node
    #@param [Integer] mask        Netmask
    #@param [String]  default_id  Middleware ID of default(specify only during the test)
    #@return [void]
    #
    def setup(ip, mask, default_id=nil)
        log_trace(ip, mask, default_id)

        EventCollector.setup()
        NCPS.create($ncps_network, {
            :ip             => ip,
            :mask           => mask,
            :port           => $config[:ctrl_port],
            :data_port_base => $config[:data_port_base],
            :data_port_max  => $config[:data_port_max],
            :cmd_port       => $config[:cmd_port],
            :stdin          => $stdin,
            :request_slice  => $config[:request_slice],
        })
        # To notify the start of middleware to the NCPS.
        begin
            @middleware_id, service_server = NCPS.start()
            if not default_id.nil?()
                @middleware_id = default_id
            end
            log_info("middleware ID(=#{@middleware_id}) is registerd successfully.")

            #rescue NetworkError, InternalServerError, Timeout::Error
        rescue
            log_warn("can not connect to NCPS Server. retry to connect NCPS Server.")
            sleep(1)
            retry
        end

        Stats.start($config[:statistics_interval])
        Supervisor.setup(@middleware_id, service_server)
        DSNExecutor.setup(@middleware_id, $config[:dsn_observe_interval], $config[:dsn_auto_execute_interval])
    end

    # To start the RPC server.
    #
    #@return [void]
    #
    def start()
        log_trace()

        scn_rpc_server = SCNManagerRPCServer.new()
        scn_rpc_server.start()

        puts "'SCN middleware' started."
        log_info("SCN Manager start.")
        log_debug() {"RPC receive server start. (RPC RX port = #{@rpc_initial_rx_port})"}

        @rpc_server = MessagePack::RPC::Server.new
        @rpc_server.listen("0.0.0.0", @rpc_initial_rx_port, scn_rpc_server)
        @rpc_server.run
    end

    # It performs a leave notification of SCN middleware, to stop the various threads.
    #
    #@return [void]
    #@todo To implement the stop processing.
    #
    def stop()
        log_trace()

        begin
            NCPS.stop()
        rescue
            # To continue the process to ignore the exception that occurred.
        end
        log_info("middleware ID(=#{@middleware_id}) is unregisterd.")
    end
end

#= RPC server class for the initial communication with the application
#  PC server that accepts the initial connection from the application.
#
#@author NICT
#
class SCNManagerRPCServer

    def initialize()
        @rpc_rx_port       = $config[:rpc_rx_port]
        @rpc_tx_port_base  = $config[:rpc_tx_port_base]
        @rpc_ip_address    = $config[:rpc_ip_address]

        @application_rpc = ApplicationRPC.new(@rpc_rx_port, @rpc_ip_address)
        @application_count = 1
    end

    # To start the application server.
    #
    def start()
        @application_rpc.start()
    end

    # To start the RPC server with the application, to notify the receiving port of the application side
    #
    #@return [Array]
    #  (Integer) Transmission port of application side
    #  (Integer) Receiving port of application side
    #
    def connect_app()
        log_trace()

        rpc_tx_port = get_rpc_tx_port()
        log_info("RPC TX port = #{rpc_tx_port}")

        # Receiving port of the SCN side is to the transmission port of the application side.
        # Transmission port of the SCN side is to the receiving port of the application side.
        return @rpc_rx_port, rpc_tx_port
    end

    private

    # Method to issue the transmission port number of SCN side
    #
    #@return [Integer] Transmission port of SCN side
    #
    def get_rpc_tx_port()
        rpc_tx_port = @rpc_tx_port_base + @application_count
        @application_count += 1

        return rpc_tx_port
    end
end

