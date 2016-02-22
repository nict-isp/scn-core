#-*- coding: utf-8 -*-
require_relative '../../utils'
require_relative '../../utility/m2m_format'
require_relative '../compile/conditions'

#= Base class of intermediate processing
#
#@author NICT
#
class Processing
    include DSN

    #@param [Hash] conditions  Intermediate processing request
    #
    def initialize(conditions)
        @conditions = conditions
    end

    # To execute an intermediate processing.
    #
    #@param [Hash] processing_data  Intermediate processing data
    #@return Data after the intermediate processing run (the same format as the input data)
    #
    def execute(processing_data)
        return processing_data
    end

    private

    # The value of the intermediate processing target is taken out by the method of Enumrable,
    # to perform the process by the block statement.
    #
    #@param [Hash]      processing_data  Intermediate processing data
    #@param [Symbol]    method_name      Method name of Enumerable
    #@yieldparam [Hash] value            Extracted data elements
    #@yieldreturn [Object] Return value of the Enumerable  method
    #@return [Hash]        Intermediate processing data after processing by Enumerable method
    #
    def processing_values(processing_data, method_name, &block)
        if M2MFormat.formatted?(processing_data)
            result = processing_m2m_values(processing_data, method_name, &block)
        else
            result = processing_normal_values(processing_data, method_name, &block)
        end
        return result
    end

    # The value of the data which does not correspond to M2M data taken out by the method of Enumrable,
    # to execute the process by the block statement.
    #
    #@param [Hash]      processing_data  Intermediate processing data
    #@param [Symbol]    method_name      Method name of Enumerable
    #@yieldparam [Hash] value            Extracted data elements
    #@yieldreturn [Object] Return value of the Enumerable  method
    #@return [Hash]        Intermediate processing data after processing by Enumerable method
    #
    def processing_normal_values(processing_data, method_name)
        data = processing_data.method(method_name).call { |value|
            yield(value)
        }
        return data
    end

    # The value of the M2M data ver1.02 removed by methods of Enumrable,
    # to execute the process by the block statement.
    #
    #@param [Hash]      processing_data  Intermediate processing data
    #@param [Symbol]    method_name      Method name of Enumerable
    #@yieldparam [Hash] value            Extracted data elements
    #@yieldreturn [Object] Return value of the Enumerable  method
    #@return [Hash]        Intermediate processing data after processing by Enumerable method
    #
    def processing_m2m_values(processing_data, method_name)
        data = M2MFormat.clone_data(processing_data)
        values = M2MFormat.get_values(data).method(method_name).call { |value|
            # Support for Event Warehouse. To store the required data.
            value["latitude"]  ||= nil
            value["longitude"] ||= nil
            value["altitude"]  ||= nil
            value["time"]      ||= nil
            yield(value)
        }
        M2MFormat.set_values(data, values)
        return data
    end

    # A common format to be handled in the intermediate processing.
    #
    #@param [Numeric] start     Start value
    #@param [Numeric] ende      End value
    #@param [Numeric] interval  Data interval
    #@param [String]  label     Data name
    #@return [Hash] Preformatted of information
    #
    def to_info(start, ende, interval, label)
        return {
            "start"    => start,
            "end"      => ende,
            "interval" => interval,
            "label"    => label
        }
    end
end

#@private
#= Space-time processing module
#
#@author NICT
#
module TimeSpaceProcessing

    private

    # To calculate the index of aggregate destination.
    #
    #@param [Hash] info  Definition information for aggregate (data name, start value, end value, interval)
    #@param [Hash] data  Sensor data
    #@return [Integer] Index of aggregate destination
    #@return [Nil]     It exceeds the aggregate range
    #
    def get_index(info, data)
        value = data[info["label"]]
        start = info["start"]
        ende  = info["end"]
        value = yield(value) if block_given?    # Converted to computable numbers.
        return (start <= value && value < ende) ? ((value - start) / info["interval"]).to_i : nil
    end

    # From the aggregation destination of the index, to calculate the aggregate range applicable.
    #
    #@param [Hash]    info   Definition information for aggregate (data name, start value, end value, interval)
    #@param [Integer] value  Index of aggregate destination
    #@retrun [Object, Object] Start value, End value
    #
    def get_start_end(info, value)
        interval = info["interval"]
        start = value * interval + info["start"]
        ende  = [start + interval, info["end"]].min # So as not to exceed an aggregate range.
        start = yield(start) if block_given?        # It is converted to the format of the original data.
        ende  = yield(ende)  if block_given?        # It is converted to the format of the original data.
        return start, ende
    end

    # To get the time information into a form that handled by intermediate processing.
    #
    #@param [Hash] time  Hash of the time information
    #@return [Hash] Preformatted time information
    #
    def get_time_info(time)
        if time.kind_of?(Hash)
            time_unit_str = time["time_unit"]
            case time_unit_str
            when "second"
                time_unit = 1
            when "minute"
                time_unit = 60
            when "hour"
                time_unit = 60 * 60
            else
                log_warn("undefined time unit. (time_unit=#{time_unit_str})")
                time_unit = 1
            end
            time_info = to_info(
            time_to_sec(time["start_time"]),
            time_to_sec(time["end_time"]),
            time["time_interval"] * time_unit,
            time["data_name"]
            )
            time_info["unit"] = time_unit
        else
            time_info = nil
        end
        return time_info
    rescue
        log_error("invalid processing request. (time info#{time})", $!)
        return nil
    end

    # To get in the form of dealing with spatial information at intermediate processing.
    #
    #@param [Hash] time  Hash of spatial information
    #@return [Hash, Hash] Preformatted of latitude information and longitude information
    #
    def get_space_info(space)
        if space.kind_of?(Hash)
            latitude_info  = to_info(space["south"], space["north"], space["lat_interval"],  space["lat_data_name"])
            longitude_info = to_info(space["west"],  space["east"],  space["long_interval"], space["long_data_name"])
        else
            latitude_info  = nil
            longitude_info = nil
        end
        return latitude_info, longitude_info
    rescue
        log_error("invalid processing request. (space info#{space})", $!)
        return nil, nil
    end
end

