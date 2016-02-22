# -*- coding: utf-8 -*-
require_relative './base_method'

module DSN

    #= SpaceMethod class
    # To analyze the DSN description space method.
    #
    #@author NICT
    #
    class SpaceMethod < BaseMethod
        METHOD_NAME = "space"

        # Order of the arguments of the method
        POS_LAT_DATA_NAME = 0
        POS_LONG_DATA_NAME = 1
        POS_WEST = 2
        POS_SOUTH = 3
        POS_EAST = 4
        POS_NORTH = 5
        POS_LAT_INTERVAL = 6
        POS_LONG_INTERVAL = 7

        def initialize( args_data )
            @lat_data_name = args_data[POS_LAT_DATA_NAME]
            @long_data_name = args_data[POS_LONG_DATA_NAME]
            @west = args_data[POS_WEST]
            @south = args_data[POS_SOUTH]
            @east = args_data[POS_EAST]
            @north = args_data[POS_NORTH]
            @lat_interval = args_data[POS_LAT_INTERVAL]
            @long_interval = args_data[POS_LONG_INTERVAL]
        end

        # It determines whether the character string corresponding to the space method.
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # To analyze the space method syntax.
        #
        #@param [DSNText] text  String of method
        #@return [Array<Integer|Float|String>] Array of arguments of the method
        #@raise [ArgumentError] Not in the correct format as a method
        #
        def self.parse(text)
            format = [[TYPE_DATANAME],[TYPE_DATANAME],[TYPE_INTEGER, TYPE_FLOAT],[TYPE_INTEGER, TYPE_FLOAT],[TYPE_INTEGER, TYPE_FLOAT],[TYPE_INTEGER, TYPE_FLOAT],[TYPE_INTEGER, TYPE_FLOAT],[TYPE_INTEGER, TYPE_FLOAT]]

            args = BaseMethod.parse(text, METHOD_NAME, format)

            # Take out the parameters.
            args_string = args.map{|arg| arg.single_line}

            # Longitude error if from -180.0 other than 180.0.
            # Latitude error if from -90.0 other than 90.0.
            longitude_min = -180.0
            longitude_max = 180.0
            latitude_min = -90.0
            latitude_max = 90.0
            west = args_string[2]
            south = args_string[3]
            east = args_string[4]
            north = args_string[5]
            unless west.between?(longitude_min, longitude_max) \
            && east.between?(longitude_min, longitude_max) \
            && south.between?(latitude_min, latitude_max) \
            && north.between?(latitude_min, latitude_max)
                msg = "(west, south, east, north) = (#{west}, #{south}, #{east}, #{north})"
                raise DSNFormatError.new(ErrorMessage::ERR_SPACE_RANGE, text, msg)

            end

            # Error in the case of west> east and south> north.
            longitude_diff = west - east
            latitude_diff = south - north
            if longitude_diff > 0 || latitude_diff > 0
                msg = "(west, south, east, north) = (#{west}, #{south}, #{east}, #{north})"
                raise DSNFormatError.new(ErrorMessage::ERR_SPACE_BACK, text, msg)
            end

            return SpaceMethod.new(args_string)
        end

        # It is converted into an intermediate code.
        def to_hash()
            return {KEY_SPACE => {
                KEY_LAT_DATA_NAME => @lat_data_name,
                KEY_LONG_DATA_NAME => @long_data_name,
                KEY_WEST => @west,
                KEY_SOUTH => @south,
                KEY_EAST => @east,
                KEY_NORTH => @north,
                KEY_LAT_INTERVAL => @lat_interval,
                KEY_LONG_INTERVAL => @long_interval
                }}
        end
    end
end
