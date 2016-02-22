#-*- coding: utf-8 -*-
require_relative './processing'

#@private
#= Aggregation and integration process definition class
#
module AggregateDefine
    # item
    NAME  = "name"

    UNIT  = "unit"
    EAST  = "east"
    WEST  = "west"
    NORTH = "north"
    SOUTH = "south"
    START = "start"

    ENDE  = "end"
    MAX   = "max"
    MIN   = "min"
    AVG   = "avg"
    SUM   = "sum"
    COUNT = "count"
end

#= Aggregation and integration process definition class(for inner service)
#
#@author NICT
#
class Aggregate < Processing
    include AggregateDefine
    include TimeSpaceProcessing

    #@param [Hash] conditions  Intermediate processing request
    #
    def initialize(conditions)
        super

        reset()
        update(conditions)
    end

    # To update the intermediate processing request. 
    # 
    #@param [Hash] conditions  Intermediate processing request
    #@return [void]
    #
    def update(conditions)
        @conditions = conditions

        @name  = conditions["data_name"]
        @delay = conditions["delay"]
        space = conditions["space"]
        if space.nil?
            @latitude, @longitude = [nil, nil]
        else
            @latitude, @longitude = get_space_info(space)
        end
    end

    # To execute the aggregation and integration process.
    # After dividing the space into specified intervals, to aggregate the data having the same index.
    #
    #@param [Hash] processing_data  Intermediate processing data
    #@retrun [Array] Empty data(in order to once aggregated)
    #
    def execute(processing_data)
        processing_values(processing_data, :each) { |value|
            if @time < time_to_sec(value["time"]) + @delay && value.has_key?(@name)
                key = get_key(value)
                @cache[key] << value
            end
        }   
        return []
    end

    # Return by aggregating the accumulated data. Accumulated data is cleared.
    #
    #@return Data was subjected to aggregation and integration process
    #@example aggregation and integration data
    #[
    #   {
    #       "name" => "rainfall",
    #       "west" => 130.0, "east" => 131.0,
    #       "south" => 35.0, "north" => 36.0,
    #
    #       "start" => "2015/01/01T00:00:00",
    #       "end"   => "2015/01/01T00:00:30",
    #
    #       "max"   => 30.0,
    #       "min"   => 5.0,
    #       "avg"   => 10.0,
    #       "sum"   => 1000.0,
    #       "count" => 100,
    #   }, {
    #       "name" => "rainfall",
    #       "west" => 131.0, "east" => 132.0,
    #       "south" => 35.0, "north" => 36.0,
    #
    #       "start" => "2015/01/01T00:00:00",
    #       "end"   => "2015/01/01T00:00:30",
    #
    #       :
    #   }
    #]
    #
    def get_result()
        log_trace()
        result = []

        now  = Time.now.to_i
        info = {
            START => sec_to_time(@time),
            ENDE  => sec_to_time(now),
        }
        @cache.each do |(lat, long), values|
            if @latitude.nil?
                # If it does not have a designated space, the range of the space to cover all the data.
                info[SOUTH], info[NORTH] = values.each_with_object([]) {|v, a| a << v["latitude"]}.minmax
                info[WEST],  info[EAST]  = values.each_with_object([]) {|v, a| a << v["longitude"]}.minmax
            else
                info[SOUTH], info[NORTH] = get_start_end(@latitude, lat)
                info[WEST],  info[EAST]  = get_start_end(@longitude, long)
            end

            # Aggregated for each index.
            summary = {}
            summary[SUM]   = values.inject(0) {|sum, value| sum += value[@name] }
            summary[COUNT] = values.size
            summary[AVG]   = summary[SUM] / summary[COUNT]
            summary[MIN], summary[MAX] = values.each_with_object([]) {|v, a| a << v[@name]}.minmax
            result << summary.merge(info)
        end
        log_trace(result)
        reset(now)  # To remove the output data already.
        return result
    end

    private

    # To create a key aggregate data.
    # 
    def get_key(value)
        if @latitude.nil?
            # If it does not have a designated space, all aggregated in the same key.
            return [nil, nil]
        else
            return [get_index(@latitude, value), get_index(@longitude, value)]
        end
    end

    # To clear the aggregate data.
    #
    def reset(now = nil)
        if now.nil?
            now = Time.now.to_i
        end
        @time  = now 
        @cache = SyncHash.new{|h, k| h[k] = []}
    end
end

