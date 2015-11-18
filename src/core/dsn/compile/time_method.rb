# -*- coding: utf-8 -*-
require_relative './base_method'

module DSN

    #= TimeMethodメソッドクラス
    # DSN記述のtimeメソッドを解析する。
    #
    #@author NICT
    #
    class TimeMethod < BaseMethod
        # メソッド名
        METHOD_NAME = "time"

        # メソッドの引数の順番
        POS_DATA_NAME = 0
        POS_START_TIME = 1
        POS_END_TIME = 2
        POS_TIME_INTERVAL = 3
        POS_TIME_UNIT = 4

        def initialize( args_data )
            @data_name = args_data[POS_DATA_NAME]
            @start_time = args_data[POS_START_TIME]
            @end_time = args_data[POS_END_TIME]
            @interval = args_data[POS_TIME_INTERVAL]
            @unit = args_data[POS_TIME_UNIT]
        end

        #メソッドに対応した文字列か判定する。
        #
        #@return 対応していればtrue
        #
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # timeメソッド構文を解析する。
        #
        #@param [DSNtext] text メソッドのDSNtext
        #@return [Array<Integer|Float|String>] メソッド引数の配列
        #@raise [DSNFormatError] メソッドとして,正しい形式でない場合
        #
        def self.parse(text)
            # フォーマットの定義
            format = [[TYPE_DATANAME],[TYPE_TIME],[TYPE_TIME],[TYPE_INTEGER],[TYPE_STRING]]

            args = BaseMethod.parse(text, METHOD_NAME, format)

            # 時間の単位がday, hour, minute, second以外の場合はエラー
            units = ["day", "hour", "minute", "second"]
            unless units.any?{|unit| unit == args[4].single_line}
                msg = "input: #{args[4].single_line}"
                raise DSNFormatError.new(ErrorMessage::ERR_TIME_UNIT, args[4], msg)
            end

            # starttime > endtimeの場合はエラー
            starttime = time_to_sec(args[1].single_line)
            endtime   = time_to_sec(args[2].single_line)
            if starttime > endtime
                msg = "starttime: #{args[1].single_line}, endtime: #{args[2].single_line}"
                raise DSNFormatError.new(ErrorMessage::ERR_TIME_BACK, text, msg)

            end

            # interval <= 0の場合はエラー
            if args[3].single_line <= 0
                msg = "interval: #{args[3].single_line}"
                raise DSNFormatError.new(ErrorMessage::ERR_TIME_INTERVAL, text, msg)
            end

            return TimeMethod.new(args.map{|arg| arg.single_line})
        end

        #中間コードに変換する。
        def to_hash()
            return {KEY_TIME =>{
                KEY_TIME_DATA_NAME => @data_name,
                KEY_START_TIME => @start_time,
                KEY_END_TIME => @end_time,
                KEY_TIME_INTERVAL => @interval,
                KEY_TIME_UNIT => @unit
                }}
        end
    end

end
