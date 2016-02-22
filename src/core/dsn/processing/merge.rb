#-*- coding: utf-8 -*-
require_relative './processing'

#= Merge processing class (for inner service)
#
#@author NICT
#
class Merge < Processing
    
    #@param [Hash] conditions  Intermediate processing request
    #
    def initialize(conditions = {})
        super

        reset()
        reset() # To generate up to old_cache twice call.
    end

    # To update the intermediate processing request. 
    # 
    #@param [Hash] conditions Intermediate processing request
    #@return [void]
    #
    def update(conditions)
        @conditions = conditions
    end

    # To execute the merge process.
    # As a key space time, merging data from multiple data sources.
    # For the merge by key, hold data always 1 operation cycle or more.
    #
    #@param [Hash] processing_data  Intermediate processing data
    #@retrun [Array] Empty data (for once retained)
    #
    def execute(processing_data)
        processing_values(processing_data, :each) { |value|
            key = get_key(value)

            # To make sure it matches the data in the hold.
            if @old_cache.has_key?(key)
                @old_cache[key].merge!(value)
            else
                @new_cache[key].merge!(value)
            end
        }   
        return []
    end

    # To get the result merge aligned in space-time.
    #
    #@return [Array<Hash>] Data that are aligned in space-time
    #
    def get_result()
        log_trace()
        result = @old_cache.values.sort_by{|value| get_key(value)}
        reset()
        return result
    end

    private

    # To generate a key space-time to be used in the hash and sort.
    #
    def get_key(value)
        return [[value["time"]], [value["latitude"]], [value["longitude"]]]
    end

    def reset()
        @old_cache = @new_cache
        @new_cache = SyncHash.new{|h, k| h[k] = {}}
    end
end

