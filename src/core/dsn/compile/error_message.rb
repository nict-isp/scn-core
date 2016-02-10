# -*- coding: utf-8 -*- 
require_relative '../../utils'
require_relative './dsn_format_error'
require_relative './dsn_define'

module DSN

    #= DSN記述エラーメッセージクラス
    # DSN記述で発生するエラーメッセージを管理するクラス
    #
    #@author NICT
    #
    class ErrorMessage

        ############################
        #メソッドのフォーマット一覧#
        ############################
        #discovery構文のフォーマット
        CORRECT_DISCOVERY="@service_name: discovery(attr_name=attr_value,...)"

        #scratch構文のフォーマット
        CORRECT_SCRATCH="scratch: scratch_name, @service_name (OPTION)\nOPTION =>[data_name, data_name=data_value, data_name:data_path]"

        #channel構文のフォーマット
        CORRECT_CHANNEL="channel: channel_name, @service_name (OPTION)\nOPTION =>[data_name,...]"

        #filter構文のフォーマット
        CORRECT_FILTER="channel_name <~ scratch_name.filter(CONDITIONS)"

        #time構文のフォーマット
        CORRECT_TIME="time(time_data_name, start_time, end_time, time_interval)"
        #space構文のフォーマット
        CORRECT_SPACE="space(lat_data_name, long_data_name, west, south, east, north, lat_interval, long_interval)"

        #aggregate構文のフォーマット
        CORRECT_AGGREGATE="channel_name <~ scratch_name.aggregate(aggregate_data_name, timeout, delay, #{CORRECT_SPACE})"

        #trigger構文のフォーマット
        CORRECT_TRIGGER="event_name <+ channel_name.trigger(trigger_interval, trigger_conditions, condtions)"

        #range構文のフォーマット
        CORRECT_RANGE="range(data_name, min, max)"

        #like構文のフォーマット
        CORRECT_LIKE="like(data_name, regex)"

        #cull_time構文のフォーマット
        CORRECT_CULLTIME="channel_name <~ scratch_name.cull_time(numerator, denominator, #{CORRECT_TIME})"

        #cull_space構文のフォーマット
        CORRECT_CULLSPACE="channel_name <~ scratch_name.cull_space(numerator, denominator, #{CORRECT_SPACE})"

        #string構文のフォーマット
        CORRECT_STRING="channel_name <~ scratch_name.string(data_name, removeBlanks|removeSpecialChars|lowerCase|upperCase|concat|alphaReduce|numReduce|replace|regexReplace, [param1], [param2])"

        #string構文のフォーマット(パラメタなし)
        CORRECT_STRING0="channel_name <~ scratch_name.string(data_name, operator)"

        #string構文のフォーマット(パラメタ1つ)
        CORRECT_STRING1="channel_name <~ scratch_name.string(data_name, operator, param1)"

        #string構文のフォーマット(パラメタ2つ)
        CORRECT_STRING2="channel_name <~ scratch_name.string(data_name, operator, param1, param2)"

        #merge構文のフォーマット
        CORRECT_MERGE="channel_name.merge(delay, channel_name1, channel_name2, ...)"
        #join構文のフォーマット
        CORRECT_JOIN="channel_name.join(delay, virtual_prop_name, virtual_prop_expr, channel_name1, channel_name2, ...)"

        #virtual構文のフォーマット(パラメタ1つ)
        CORRECT_VIRTUAL="channel_name <~ scratch_name.virtual(virtual_prop_name, virtual_prop_expr)"

        #メソッド名に対応するフォーマットのハッシュ
        FORMAT_HASH = {
            KEY_CULL_SPACE => CORRECT_CULLSPACE,
            KEY_CULL_TIME  => CORRECT_CULLTIME,
            KEY_LIKE       => CORRECT_LIKE,
            KEY_RANGE      => CORRECT_RANGE,
            KEY_TRIGGER    => CORRECT_TRIGGER,
            KEY_AGGREGATE  => CORRECT_AGGREGATE,
            KEY_SPACE      => CORRECT_SPACE,
            KEY_TIME       => CORRECT_TIME,
            KEY_FILTER     => CORRECT_FILTER,
            KEY_CHANNEL    => CORRECT_CHANNEL,
            KEY_SCRATCH    => CORRECT_SCRATCH,
            KEY_DISCOVERY  => CORRECT_DISCOVERY,
            KEY_STRING     => CORRECT_STRING,
            KEY_MERGE      => CORRECT_MERGE,
            KEY_JOIN       => CORRECT_JOIN,
            KEY_VIRTUAL    => CORRECT_VIRTUAL,
        }

        ######################
        #エラーメッセージ一覧#
        ######################
        #base_method.rb
        #メソッドのフォーマットとして、妥当でない場合。
        CORRECT_FORMAT_METHOD="method_name(arg1,arg2,...)"
        ERR_FORMAT_METHOD = "The format of the method is not correct.The correct format is #{CORRECT_FORMAT_METHOD}"

        #RuntimeError向け（ソースコード実装エラー）
        ERR_INTERFACE = "This class is interface. This method must not be called."

        #service.rb
        #discoveryメソッドのattrが正しく分離できない場合
        ERR_DISCOVERY_ATTR = "Cannot to get valid attribute of discovery method."

        #servicelinks.rb
        #定義されていないscratch nameを利用しようとした場合
        ERR_UNKNOWN_SCRATCH = "The scratch name is not defined in state do block."

        #servicelinks.rb
        #定義されていないchannel nameを利用しようとした場合
        ERR_UNKNOWN_CHANNEL = "The channel name is not defined in state do block."

        #dsn_text.rb
        #切り出した文字列内の括弧が閉じていない場合
        ERR_BRACKET_UNCLOSED = "The bracket is not closed."

        #dsn_text.rb
        #切り出した文字列内の閉じ括弧が余分な場合
        ERR_TOO_MANY_BRACKET = "Too many brackets is closed."

        #dsn_text.rb
        #切り出した文字列内のダブルクォートが閉じていない場合
        ERR_DQUOTE_UNCLOSED = "The double quote is not closed."

        #dsn_text.rb
        #文字列の外側で、\"(エスケープ＋ダブルクォート)を使用した場合
        ERR_ESCAPE_DQUOTE = "Cannot use \\\" outside of string."

        #condition.rb
        #引数が整数, 実数，ダブルクォートで囲まれた文字列の
        #いずれにも合致しない場合
        ERR_ARGUMENT_FORMAT = "The Argument format must be described as Integer, Float or String(enclose words in \" \")."

        #condition.rb
        #データ名のフォーマットに誤りがある場合
        ERR_DATANAME_FORMAT = "The data_name format is wrong."

        #
        #state doブロックが存在しない場合
        ERR_NO_STATE = "The \"state do end\" block must be needed."

        #
        #state doブロックが複数定義されている場合
        ERR_MULTI_STATE = "The \"state do end\" block must be defined only once."

        #
        #bloom doブロックが存在しない場合
        ERR_NO_BLOOM = "The \"bloom do end\" block must be needed."

        #
        #bloom doブロックが複数定義されている場合
        ERR_MULTI_BLOOM = "The \"bloom do end\" block must be defined only once."

        #
        #構文の終端が存在しない場合
        ERR_NO_TERMINATOR = "There is no terminator of DSN syntax."

        #
        #ブロックに対応するendが存在しない場合
        ERR_NO_END = "There is no \"end\" terminator."

        #
        #不要なendが存在しない場合
        ERR_MANY_END = "Too many \"end\" terminator."

        #
        #センテンスがブロックの外側に定義されている場合
        ERR_OUT_BLOCK = "The sentense must be defined inside a block."

        #
        #センテンスに設定されているイベント名が未定義の場合
        ERR_EVENT_UNDEFINED = "The event name which specified in the sentence is undefined."

        #
        #センテンスに予約語が不正使用されている場合
        ERR_USE_RESERVED = "The reserved word is prohibited that using as “scratch name\", “channel name\" and “event name\"."

        #
        #discovery構文のフォーマットが間違っていた場合
        ERR_DISCOVERY_FORMAT = "The format is not correct in discovery method.\nCorrect format is:\n#{CORRECT_DISCOVERY}"

        #
        #サービス名が重複していた場合
        ERR_SERVICE_DUPLICATE = "The service name is duplicate."

        #
        #scratch構文のフォーマットが間違っていた場合
        ERR_SCRATCH_FORMAT = "The format is not correct in scratch method.\nCorrect format is:\n#{CORRECT_SCRATCH}"

        #
        #サービス名が未定義の場合
        ERR_SERVICE_UNDEFINED = "The service name is undefined."

        #
        #channel構文のフォーマットが間違っていた場合
        ERR_CHANNEL_FORMAT = "The format is not correct in channel method.\nCorrect format is:\n#{CORRECT_CHANNEL}"

        #
        #channel構文のフォーマットが間違っていた場合
        ERR_OPTION_FORMAT = "The format is not correct options of scratch or channel."

        #
        #scratch名がstate doブロックで未定義の場合
        ERR_SCRATCH_UNDEFINED = "The \"scratch name\" must be defined in \"state do end\" block."

        #
        #scratch名が重複していた場合
        ERR_SCRATCH_DUPLICATE = "The \"scratch name\" is duplicate."

        #
        #channel名がstate doブロックで未定義の場合
        ERR_CHANNEL_UNDEFINED = "The \"channel name\" must be defined in \"state do end\" block."

        #
        #channel名が重複していた場合
        ERR_CHANNEL_DUPLICATE = "The \"channel name\" is duplicate."

        #
        #channel nameに設定されているdata nameがscratch nameに含まれない場合
        ERR_CHANNEL_SCRATCH_MISMATCH = "The data_name is not consistent with in setting \"scratch name\" and \"channel name\"."

        #
        #filter構文のフォーマットが間違っていた場合
        ERR_FILTER_FORMAT = "The format is not correct in filter method.\nCorrect format is:\n#{CORRECT_FILTER}"

        #指定されたdata nameがscratch nameに設定されていない場合
        ERR_DATA_UNDEFINED = "The data_name specified in condition sentence is not set in scratch name."

        #
        #aggregate構文のフォーマットが間違っていた場合
        ERR_AGGREGATE_FORMAT = "The format is not correct in aggregate method.\nCorrect format is:\n#{CORRECT_AGGREGATE}"

        #
        #time構文のフォーマットが間違っていた場合
        ERR_TIME_FORMAT = "The format is not correct in time method.\nCorrect format is:\n#{CORRECT_TIME}"

        #
        #time構文のunit指定が間違っていた場合
        CORRECT_TIME_UNIT="[\"day\", \"hour\", \"minute\", \"second\"]"
        ERR_TIME_UNIT = "The unit of \"time interval\" is restricted as below.\n#{CORRECT_TIME_UNIT}"

        #
        #time構文のinterval指定が間違っていた場合
        ERR_TIME_INTERVAL = "The time interval is restricted as positive integer."

        #
        #time構文でstarttime > endtimeが指定された場合
        ERR_TIME_BACK = "Specified StartTime and EndTime are reversed."

        #
        #time構文の緯度経度指定が間違っていた場合
        ERR_SPACE_RANGE = "The longitude(-180.0 to 180.0) and latitude(-90.0 to 90.0) values must be in each range."

        #
        #time構文の緯度経度指定が逆になっていた場合
        ERR_SPACE_BACK = "Specified longitude(west, east) or latitude(south, north) are reversed."

        #
        #trigger構文のフォーマットが間違っていた場合
        ERR_TRIGGER_FORMAT = "The format is not correct in trigger method.\nCorrect format is:\n#{CORRECT_TRIGGER}"

        #
        #trigger構文のconditionが間違っていた場合
        ERR_TRIGGER_CONDITION = "The data name of \"trigger condition\" is restricted \"count\" only.:Correct format is:\n#{CORRECT_TRIGGER}"

        #
        #trigger構文のintervalが0以下となっていた場合
        ERR_TRIGGER_INTERVAL = "The trigger interval must be a positive integer."

        #
        #""の終端が定義されていない場合
        ERR_DQUOTE_TERMINATOR = "There is no double quote terminator."

        #
        #()の終端が定義されていない場合
        ERR_BRACKET_TERMINATOR = "There is no bracket terminator."

        #
        #range構文の最小・最大値型が異なる場合
        ERR_RANGE_TYPE = "The minimum and maximum values must be same data type."

        #
        #range構文の最小・最大指定が逆の場合
        ERR_RANGE_BACK = "The minimum value is larger than maximum value."

        #
        #メソッド引数として期待されているのと異なる型が記述されていた場合
        ERR_DATA_TYPE = "The argument format is not correct in this method."

        #
        #メソッド引数の数が期待される数と異なる場合
        #正しいフォーマットを表示
        ERR_ARGUMENTS = "The format is not correct in this method.\nCorrect format is:\n"

        #
        #cull_time構文の分子・分母が不正な場合
        ERR_CULL_VALUE = "The numerator or denominator is invalid value. It expected positive integer and numerator/denominator <= 1."

        #
        #Condition文として解釈できない入力があった場合
        ERR_NO_CONDITION = "The input phrase cannot read as a Condition phrase."

        #
        #transmission構文として無効なメソッドが指定された場合
        ERR_TRANSMISSION_METHOD = "The specified method is not valid on transmission phrase(right side of \"<~\" operator)."

        #
        #merge構文として無効なメソッドが指定された場合
        ERR_MERGE_PROCESSING_METHOD = "The specified method is not valid on merge phrase(right side of \"merge\" method)."

        #
        #event do ブロック内でevent doを検出(入れ子)
        ERR_NESTED_EVENTDO = "The specified method is not valid on transmission phrase(right side of \"<~\" operator)."

        #
        # 有効なDSN記述ブロック/構文と一致しない
        ERR_NOT_MATCH_SYNTAX = "This line does not match any enable DSN syntax."

        #
        #string構文のフォーマットが間違っていた場合
        ERR_STRING_FORMAT = "The format is not correct in string method.\nCorrect format is:\n#{CORRECT_STRING}"

        #
        #string構文(パラメタなし)のフォーマットが間違っていた場合
        ERR_STRING_FORMAT0 = "The format is not correct in string method.\nCorrect format is:\n#{CORRECT_STRING0}"

        #
        #string構文(パラメタ1つ)のフォーマットが間違っていた場合
        ERR_STRING_FORMAT1 = "The format is not correct in string method.\nCorrect format is:\n#{CORRECT_STRING1}"

        #
        #string構文(パラメタ2つ)のフォーマットが間違っていた場合
        ERR_STRING_FORMAT2 = "The format is not correct in string method.\nCorrect format is:\n#{CORRECT_STRING2}"

        #merge構文のフォーマットが間違っていた場合
        ERR_MERGE_METHOD = "The format is not correct in merge method.\nCorrect format is:\n#{CORRECT_MERGE}"
        #join構文のフォーマットが間違っていた場合
        ERR_JOIN_METHOD = "The format is not correct in join method.\nCorrect format is:\n#{CORRECT_JOIN}"
    end
end
