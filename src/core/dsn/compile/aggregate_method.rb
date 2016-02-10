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

        def initialize(data, timeout, delay, space)
            @data_name      = data
            @timeout        = timeout
            @delay          = delay
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
            # 第4引数が省略可のため、まず、引数の数を取得する。
            format = nil
            args = BaseMethod.parse(text, METHOD_NAME, format)

            # 引数の数に応じてformatを定義し、再paraseする。
            if args.size() == 4
                format = [[TYPE_DATANAME],[TYPE_INTEGER],[TYPE_INTEGER],[TYPE_ANY]]
            else
                format = [[TYPE_DATANAME],[TYPE_INTEGER],[TYPE_INTEGER]]
            end
            args = BaseMethod.parse(text, METHOD_NAME, format)

            dataname = args[0].single_line
            timeout  = args[1].single_line
            delay    = args[2].single_line
            space    = args.size() == 4 ? SpaceMethod.parse(args[3]) : nil

            return AggregateMethod.new(dataname, timeout, delay, space)
        end

        #中間コードに変換する。
        def to_hash()
            space = @space_instance.nil?() ? nil : @space_instance.to_hash[KEY_SPACE]
            return {
                KEY_AGGREGATE => {
                    KEY_AGGREGATE_DATA_NAME => @data_name,
                    KEY_TIMEOUT             => @timeout,
                    KEY_DELAY               => @delay,
                    KEY_SPACE               => space
                }}
        end

    end

end
