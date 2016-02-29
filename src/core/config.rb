# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#

########
# main #
########
# Initial reception port for RPC
@rpc_initial_rx_port = 10000

# Port for RPC reception
@rpc_rx_port = 21001

# Base port for RPC transmission
@rpc_tx_port_base = 22000

# IP address for RPC transmission
@rpc_ip_address = "127.0.0.1"

##########
# Logger #
##########
$log_file          = ENV['HOME'] + "/log/scn.log"
#$logger            = Logger.new(STDOUT)
$logger            = Logger.new($log_file, 'daily', File::WRONLY | File::CREAT)
$logger.formatter  = Class.new(Logger::Formatter) {

    def initialize(*args)
        super

        @log_format  = "[%s.%03d |#{`hostname`.strip}] %5s -- %s: %s\n"
        @date_format = "%Y-%m-%d %H:%M:%S"
    end

    def call(severity, time, progname, msg)
        @log_format % [time.strftime(@date_format), time.usec / 1000, severity, progname, msg2str(msg)]
    end
}.new

# FATAL | ERROR | WARN | INFO | DEBUG
$logger.level      = Logger::ERROR
$benchmark         = false
$trace             = false

###################
# EventCollector ##
###################
@hostname = `hostname`.strip
# When true, to notify the event to the Visualizer (Redis)
@event_collecting  = true

# When true, to record the event in the log file
@event_logging     = true
@event_logging_dir = ENV['HOME'] + "/log/redis_#{@hostname}"

# Setting of fluentd
@fluent_port       = 24224
@fluent_ip_address = "172.18.102.1"

##################
# DSNExecutor #
##################
# The operation period of the DSN automatic execution[s]
@dsn_auto_execute_interval = 60
# The operation period of the DNS event monitoring[s]
@dsn_observe_interval = 5

# Storage directory of the DSN file that is automatically executed
@dsn_store_path = ENV['HOME'] + "/dsn"
# Extension of the DSN file that is automatically executed
@dsn_file_ext = ".dsn"
# Storage directory of DSN execution log
@dsn_log_store_path = ENV['HOME'] + "/dsn/log"
# Extension of DSN execution log file
@dsn_log_file_ext = ".log"

##############
# Translator #
##############
# Transmission cycle of the node information[s]
@statistics_interval = 30

###############
# NCPS Client #
###############
# Network type
$ncps_network = "OpenFlow"
#$ncps_network = "TCP"

# Base port for data message
@data_port_base = 11001

# The upper limit of the port for the data message
@data_port_max = 20000

# Port for the control message
@ctrl_port = 20001

# The maximum number of broadcasts request
@request_slice = 100

# Submit the presence or absence of HeartBeat packet
@use_heart_beat = false

# Transmission cycle of HeartBeat packet[s]
@heart_beat_interval = 5

# Port for communication with the NCPS Server
@cmd_port = 31001

$config = Hash.new
instance_variables.each {|name|
    $config[name[1..-1].to_sym] = instance_variable_get(name)
}

