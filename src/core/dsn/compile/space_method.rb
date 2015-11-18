# -*- coding: utf-8 -*-
require_relative './base_method'

module DSN

    #= SpaceMethodメソッドクラス
    # DSN記述のspaceメソッドを解析する。
    #
    #@author NICT
    #
    class SpaceMethod < BaseMethod
        # メソッド名
        METHOD_NAME = "space"

        #メソッドの引数順番
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

        #メソッドに対応した文字列か判定する。
        #
        #@return 対応していればtrue
        #
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # spaceメソッド構文を解析する。
        #
        #@param [DSNtext] text メソッドの文字列
        #@return [Array<Integer|Float|String>] メソッドの引数の配列
        #@raise [ArgumentError] メソッドとして,正しい形式でない場合
        #
        def self.parse(text)
            # フォーマットの定義
            format = [[TYPE_DATANAME],[TYPE_DATANAME],[TYPE_INTEGER, TYPE_FLOAT],[TYPE_INTEGER, TYPE_FLOAT],[TYPE_INTEGER, TYPE_FLOAT],[TYPE_INTEGER, TYPE_FLOAT],[TYPE_INTEGER, TYPE_FLOAT],[TYPE_INTEGER, TYPE_FLOAT]]

            args = BaseMethod.parse(text, METHOD_NAME, format)

            # パラメタ取り出し
            args_string = args.map{|arg| arg.single_line}

            # 経度が-180.0 ～ 180.0以外の場合はエラー
            # 緯度が-90.0 ～ 90.0以外の場合はエラー
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

            # west > east, south > northの場合はエラー
            longitude_diff = west - east
            latitude_diff = south - north
            if longitude_diff > 0 || latitude_diff > 0
                msg = "(west, south, east, north) = (#{west}, #{south}, #{east}, #{north})"
                raise DSNFormatError.new(ErrorMessage::ERR_SPACE_BACK, text, msg)

            end

            return SpaceMethod.new(args_string)
        end

        #中間コードに変換する
        #
        #@return [Hash<String,String>] 中間コード
        #
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
