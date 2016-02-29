#-*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative './processing'

#= Base class of the culling process
#
#@author NICT
#
class Cull < Processing
    include TimeSpaceProcessing

    #@param [Hash] conditions  Intermediate processing request
    #
    def initialize(conditions)
        super
        @numerator   = conditions["numerator"]
        @denominator = conditions["denominator"]
    end

    private

    # It determines whether the culling object.
    # If the result of the remainder operation by the denominator is equal
    # to or larger than the numerator, and culling object.
    #
    #@param [Integer] index  Index of the data
    #@return [True]  It is a culling target
    #@return [False] Not a culling target
    #
    def cull?(index)
        return index.nil? || (index % @denominator) >= @numerator
    end
end

#= Class of culling process by the time
#
#@author NICT
#
class CullTime < Cull

    #@param [Hash] conditions  Intermediate processing request
    #
    def initialize(conditions)
        super
        @time = get_time_info(conditions["time"])
    end

    # To execute the culling process by the time.
    # After dividing the time axis into specified intervals,
    # determines a culling object in a remainder calculation for the index.
    # Send only the not culling object data.
    #
    #@example culling example by time
    # denominator = 3, numerator = 2
    #
    # index
    # 0123456789..
    # ++-++-++-+..
    #
    # +: transmission target
    # -: culling target
    #@param [Hash] processing_data  Intermediate processing data
    #@return Data was subjected to culling by time(the same format as the input data)
    #
    def execute(processing_data)
        return processing_values(processing_data, :select) { |value|
            time_index = get_index(@time, value) { |time| time_to_sec(time) }
            not(cull?(time_index))
        }
    end
end

#= Class of culling process by the space
#
#@author NICT
#
class CullSpace < Cull

    #@param [Hash] conditions  Intermediate processing request
    #
    def initialize(conditions)
        super
        @latitude, @longitude = get_space_info(conditions["space"])
    end

    # To execute the culling process by the time.
    # After splitting the axis of the latitude and longitude to the specified interval,
    # to determine the thinning-out target in the remainder calculation for the index.
    # Send only the not culling object data.
    #
    #@example culling example by space
    # denominator = 3, numerator = 2
    #
    # index
    # \0123456789..
    # 0++-++-++-+
    # 1++-++-++-+
    # 2----------..
    # 3++-++-++-+
    # 4++-++-++-+
    # :     :
    #
    # +: transmission target
    # -: culling target
    #@param [Hash] processing_data  Intermediate processing data
    #@return Data was subjected to culling by space(the same format as the input data)
    #
    def execute(processing_data)
        return processing_values(processing_data, :select) { |value|
            lat_index  = get_index(@latitude, value)
            long_index = get_index(@longitude, value)
            (not(cull?(lat_index))) && (not(cull?(long_index)))
        }
    end
end

