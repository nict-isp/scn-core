# -*- coding: utf-8 -*-
require 'logger'
require 'ipaddr'
require 'json'
require 'time'

require_relative './errors'
load 'config.rb'

# To deep copy the object.
#
#@param [Object] obj  Object to deep copy
#@return  Deep copied object
#
def deep_copy(obj)
    return Marshal.load(Marshal.dump(obj))
end

DATA_TIME_FOMAT = "%Y-%m-%dT%H%M%S"

# To convert the system in seconds to time string
#
#@param [Integer] second  System in seconds
#@return [String] Time string
#
def sec_to_time(second)
    return Time.at(second).strftime(DATA_TIME_FOMAT)
end

# To convert a time string to the system in seconds
#
#@param [String] date  Time string
#@return [Integer] System in seconds
#
def time_to_sec(date)
    return Time.parse(date).to_i
end

# Method to output the Fatal log
#
#@param [String] message  Output message
#@return [void]
#
def log_fatal(message)
    $logger.fatal(message)
end

# Method to output the Error log
#
#@param [String] message  Output message
#@return [void]
#
def log_error(message, error=nil)
    if not error.nil?()
        message << "\n#{error.inspect()}\n\t"
        message << error.backtrace().join("\n\t")
    end
    $logger.error(addruninfo(message))
end

# Method to output the Warning log
#
#@param [String] message  Output message
#@return [void]
#
def log_warn(message)
    $logger.warn(message)
end

# Method to output the Info log
#
#@param [String] message  Output message
#@return [void]
#
def log_info(message)
    $logger.info(message)
end

# Method to output the Debug log
# In order to prevent performance degradation due to character string generation cost, 
# log output string is received in block statement.
#
#@param [String] message  Output message
#@return [void]
#
def log_debug()
    $logger.debug(addruninfo(yield)) if $logger.debug?()
end

# Method to output the Trace log
#
#@param [Array<Object>] args  Caller's argument list
#@return [void]
#
def log_trace(*args)
    $logger.debug(addruninfo(args.map{ |arg| arg.to_s }.join(", "))) if $trace && $logger.debug?()
end

# Method to output the time log
# Used for performance measurement.
#
#@param [String] message   Output message
#@return [void]
#
def log_time(message=nil)
    $logger.info("TIME:" << addruninfo(message)) if $benchmark
end

# To add a program execution information to the message
#
#@param [String] message  Output message
#@return [String] String add the execution information of the program
#
def addruninfo(message)
    return "[#{self.class.name}] #{caller[1]} : #{message}"
end

# To check the format of the IP address
#
#@param [String] ipaddress  IP address
#@return [True]  Specifying the IP address is correct,
#@return [False] Specifying the IP address is incorrect
#
def set_ipaddress_ok?(ipaddress)
    log_trace(ipaddress)

    # To check the presence or absence of a specified subnet.
    if /(.+)\/.+/ =~ ipaddress
        begin
            # To check the appearance of the IP address.
            $ip = $1
            log_info("ip #{$ip}")
            IPAddr.new(ipaddress).to_s
            result = true
        rescue
            result = false
        end
    else
        result = false
    end

    return result
end

#@param [String] ipaddress  IP address
#@return [True]  It is the IP address of this node,
#@return [False] Not the IP address of this node
#
def current_node?(ipaddress)
    return ipaddress == $ip
end

# When turned into JSON, recursively calculate the data size of the object
#
#@param [Object] o  Object to be calculated
#@return [Integer]  Data size (byte)
#
def calc_size(o)
    if o.instance_of? Hash
        size = 2
        sep = 0
        o.each do |k, v|
            size += calc_size(k) + 2 + sep  #:
            if v.nil?
                size += 4   #null
            else
                size += calc_size(v)
            end
            sep = 2     #,
        end
        return size

    elsif o.instance_of? Array
        size = 2    #[]
        sep = 0
        o.each do |v|
            size += calc_size(v) + sep
            sep = 2     #,
        end
        return size

    elsif o.instance_of? String
        return o.length + 2   #""

    else
        return o.to_s.length
    end
end
