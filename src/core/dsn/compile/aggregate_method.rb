# -*- coding: utf-8 -*-
require_relative './base_method'

module DSN

    #= AggregateMethodメソッドクラス
    # DSN記述のaggregateメソッドを解析する。
    #
    #@author NICT
    #
    class AggregateMethod < BaseMethod
        # メソッド名
        METHOD_NAME = "aggregate"

        def initialize(data, time, space)
            @data_name      = data
            @time_instance  = time
            @space_instance = space
        end

        #フィルタメソッドに対応した文字列か判定する。
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # aggregateメソッド構文を解析する。
        #
        #@param [DSNtext] text メソッドの文字列
        #@return [Array<String>] メソッドの引数の配列
        #@raise [DSNFormatError] メソッドとして,正しい形式でない場合
        #
        def self.parse(text)
            # フォーマットの定義
            format = [[TYPE_DATANAME],[TYPE_ANY],[TYPE_ANY]]

            args = BaseMethod.parse(text, METHOD_NAME, format)

            dataname = args[0].single_line
            time     = TimeMethod.parse(args[1])
            space    = SpaceMethod.parse(args[2])

            return AggregateMethod.new(dataname, time, space)
        end

        #中間コードに変換する。
        def to_hash()
            space = @space_instance.to_hash
            time = @time_instance.to_hash
            return { KEY_AGGREGATE => {
                KEY_AGGREGATE_DATA_NAME => @data_name,
                KEY_TIME => time[KEY_TIME],
                KEY_SPACE => space[KEY_SPACE]
                }}
        end

    end

end
