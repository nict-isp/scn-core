# -*- coding: utf-8 -*-
require_relative './base_method'
require_relative './time_method'

module DSN

    #= CullTimeMethodメソッドクラス
    # DSN記述のcull_timeメソッドを解析する。
    #
    #@author NICT
    #
    class CullTimeMethod < BaseMethod
        # メソッド名
        METHOD_NAME = "cull_time"

        #メソッドの引数順番
        POS_DATA_NAME = 0
        POS_TIME = 1

        #@return [String] 分子
        attr_reader :numerator
        #@return [String] 分母
        attr_reader :denominator
        #@return [TimeMethod] timeメソッドのインスタンス
        attr_reader :time_instance

        #
        def initialize(numerator, denominator, time )
            @numerator     = numerator
            @denominator   = denominator
            @time_instance = time
        end

        #フィルタメソッドに対応した文字列か判定する。
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # cull_timeメソッド構文を解析する。
        #
        #@param [DSNtext] text 構文のDSNtext
        #@return [Array<String>] メソッドの引数の配列
        #@raise [DSNFormatError] メソッドとして,正しい形式でない場合
        #
        def self.parse(text)
            # フォーマットの定義
            format = [[TYPE_INTEGER],[TYPE_INTEGER],[TYPE_ANY]]
            args = BaseMethod.parse(text, METHOD_NAME, format)

            # データ名、分子と分母を取り出す
            numerator   = args[0].single_line
            denominator = args[1].single_line
            time        = TimeMethod.parse(args[2])

            # 分子・分母が0以下の場合、エラーとする
            # また、間引きの 分子 > 分母 であった場合、エラーとする
            diff = denominator - numerator
            unless numerator > 0 && denominator > 0 && diff >= 0
                msg = "numerator: #{numerator}, denominator: #{denominator}"
                raise DSNFormatError.new(ErrorMessage::ERR_CULL_VALUE, text, msg)
            end

            return CullTimeMethod.new(numerator, denominator, time)
        end

        #中間コードに変換する。
        def to_hash()
            time = @time_instance.to_hash
            return { KEY_CULL_TIME => {
                KEY_CULL_NUMERATOR => @numerator,
                KEY_CULL_DENOMINATOR => @denominator,
                KEY_TIME => time[KEY_TIME]
                }}
        end

    end

end
