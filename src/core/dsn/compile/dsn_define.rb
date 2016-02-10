# -*- coding: utf-8 -*-

module DSN

    ############################
    #  中間コードのキーワード  #
    ############################
    KEY_PROCESSING = "processing"
    KEY_TRANS_SRC = "src"
    KEY_TRANS_DST = "dst"

    KEY_CHANNEL = "channel"
    KEY_SCRATCH = "scratch"

    KEY_SELECT_NAME = "name"
    KEY_SELECT_VALUE = "value"
    KEY_SELECT_PATH = "path"

    KEY_SERVICE_LINK = "service_links"
    KEY_APP_REQUEST = "app_request"
    KEY_SELECT = "select"
    KEY_META = "meta"

    KEY_SERVICES = "services"
    KEY_OVERLAY = "overlay"

    KEY_MULTI = "multi"
    KEY_TYPE = "type"

    KEY_FILTER = "filter"
    KEY_CONDITIONS = "conditions"

    KEY_SPACE = "space"
    KEY_LAT_DATA_NAME = "lat_data_name"
    KEY_LONG_DATA_NAME = "long_data_name"
    KEY_WEST = "west"
    KEY_SOUTH = "south"
    KEY_EAST = "east"
    KEY_NORTH = "north"
    KEY_LAT_INTERVAL = "lat_interval"
    KEY_LONG_INTERVAL = "long_interval"

    KEY_TIME = "time"
    KEY_TIME_DATA_NAME = "data_name"
    KEY_START_TIME = "start_time"
    KEY_END_TIME = "end_time"
    KEY_TIME_INTERVAL = "time_interval"
    KEY_TIME_UNIT = "time_unit"
    KEY_TIMEOUT = "timeout"
    KEY_DELAY = "delay"

    KEY_VIRTUAL = "virtual"
    KEY_VIRTUAL_NAME = "virtual_name"
    KEY_VIRTUAL_EXPR = "virtual_expr"

    KEY_CULL_NUMERATOR = "numerator"
    KEY_CULL_DENOMINATOR = "denominator"
    KEY_CULL_TIME = "cull_time"
    KEY_CULL_SPACE = "cull_space"

    KEY_AGGREGATE = "aggregate"
    KEY_AGGREGATE_DATA_NAME = "data_name"

    KEY_TRIGGER_INTERVAL = "trigger_interval"
    KEY_TRIGGER_CONDITIONS = "trigger_conditions"

    KEY_MERGE = "merge"
    KEY_JOIN  = "join"
    KEY_MERGES = "merges"
    KEY_MERGE_SRC = "src"
    KEY_MERGE_DST = "dst"

    KEY_STRING = "string"
    KEY_STRING_DATA_NAME = "data_name"
    KEY_OPERATOR = "operator"
    KEY_PARAM = "param"

    KEY_TRIGGER = "trigger"
    KEY_EVENTS = "events"

    KEY_LIKE = "like"
    KEY_RANGE = "range"
    KEY_NOT = "not"
    KEY_DISCOVERY = "discovery"

    KEY_QOS="qos"
    KEY_QOS_PRIORITY="priority"
    KEY_QOS_BANDWIDTH="bandwidth"

    KEY_ID="id"

    ############################
    #  予約語のキーワード      #
    ############################

    RESERVED_AGGREGATE = "aggregate"
    RESERVED_DISCOVERY = "discovery"
    RESERVED_LIKE = "like"
    RESERVED_SPACE = "space"
    RESERVED_BLOOM = "bloom"
    RESERVED_DO = "do"
    RESERVED_NOT = "not"
    RESERVED_STATE = "state"
    RESERVED_CHANNEL = "channel"
    RESERVED_END = "end"
    RESERVED_RANGE = "range"
    RESERVED_TIME = "time"
    RESERVED_CULL_TIME = "cull_time"
    RESERVED_CULL_SPACE = "cull_space"
    RESERVED_FILTER = "filter"
    RESERVED_SCRATCH = "scratch"
    RESERVED_TRIGGER = "trigger"

    RESERVED_ARRAY = [
        RESERVED_AGGREGATE,
        RESERVED_DISCOVERY,
        RESERVED_LIKE,
        RESERVED_SPACE,
        RESERVED_BLOOM,
        RESERVED_DO,
        RESERVED_NOT,
        RESERVED_STATE,
        RESERVED_CHANNEL,
        RESERVED_END,
        RESERVED_RANGE,
        RESERVED_TIME,
        RESERVED_CULL_TIME,
        RESERVED_CULL_SPACE,
        RESERVED_FILTER,
        RESERVED_SCRATCH,
        RESERVED_TRIGGER
    ]

    ################
    #  区切り文字  #
    ################

    #state doブロック内の構文を分割する区切り文字
    STATE_SENTENCE_DELIMITER = ":"

    #DSN記述テキストの区切り文字（改行コード)
    DSN_TEXT_DELIMITER = "\n"

    #discovery構文のattrの区切り文字
    SERVICE_ATTR_DELIMITER = "="

    #scratch,channel構文の区切り文字
    COMMUNICATION_DELIMITER = ","

    #scratch,channelのオプションを指定する文字
    OPTION_DELIMITER = "=>"

    #transmission構文の区切り文字
    TRANSMISSION_DELIMITER = "<~"

    #trigger構文の区切り文字
    TRIGGER_ON_DELIMITER = "<+"
    TRIGGER_OFF_DELIMITER = "<-"

    #チャネル名の区切り文字
    SERVICELINK_DATA_NAME_DELIMITER = "::"

    #関数内の区切り文字
    METHOD_DELIMITER = ","

    ############################
    #  正規表現のフォーマット  #
    ############################
    #0個以上の空白
    REG_SPACE = "\\s*"

    #メソッド名
    REG_METHOD_NAME = "(?<method_name>\\w+)"
    CAP_INDEX_METHOD_NAME = :method_name
    #メソッドの引数キャプチャ名
    CAP_METHOD_ARG       = "method_arg"
    CAP_INDEX_METHOD_ARG = :method_arg
    #メソッドの引数
    REG_METHOD_ARG = "(?<#{CAP_METHOD_ARG}>.*)"
    #メソッドのフォーマット
    REG_METHOD_FORMAT = /^#{REG_METHOD_NAME}\(#{REG_METHOD_ARG}\)$/

    #スクラッチ名
    REG_SCRATCH = "(?<scratch_name>\\w+)"
    #プロセッシング処理
    REG_PROCESSING = "(?<processing>.+)"
    # プロセッシング処理のフォーマット
    REG_PROCESSING_FORMAT = /^#{REG_SCRATCH}\.#{REG_PROCESSING}$/

    #not修飾子つきメソッドのフォーマット
    REG_NOT_FORMAT = /^not\s+#{REG_METHOD_NAME}\(#{REG_METHOD_ARG}\)$/

    #メソッド処理の終端
    REG_METHOD_END = "\\)"

    #metaメソッドの引数
    REG_META_ARG = /^(\w+)\s*=\s*(\w+)$/

    #サービス名
    REG_SERVICE_NAME = "@\\w+"
    #サービス名を含む行を抜き出すためのフォーマット(開始条件)
    REG_SERVICE_START_FORMAT = /^@\w+\s*:\s*/
    #サービス名を含む行を抜き出すためのフォーマット(終了条件)
    REG_SERVICE_FINISH_FORMAT = /#{REG_METHOD_END}/

    #オプション
    REG_OPTION_FORMAT = "[\\w,\\s:=\\/]+"

    #コミュニケーションクラス(scratch,channel)
    REG_SCRATCH_NAME = "scratch"
    REG_CHANNEL_NAME = "channel"
    REG_SCRATCH_START_FORMAT = /^scratch\s*:\s*/
    REG_CHANNEL_START_FORMAT = /^channel\s*:\s*/
    REG_OPTION_END = "\\]"
    REG_SCRATCH_FINISH_FORMAT = /#{REG_SERVICE_NAME}/
    REG_CHANNEL_FINISH_FORMAT = /#{REG_SCRATCH_FINISH_FORMAT}/
    REG_SCRATCH_OPTION_FORMAT = /#{REG_OPTION_END}/
    REG_CHANNEL_OPTION_FORMAT = /#{REG_SCRATCH_OPTION_FORMAT}/

    #転送(transmission)クラス
    REG_CHANNEL_NAME_FORMAT = "\\w+"
    REG_SCRATCH_NAME_FORMAT = REG_CHANNEL_NAME_FORMAT
    REG_TRANSMISSION_START_FORMAT = /\w+\s*<~\s/
    REG_TRANSMISSION_FINISH_FORMAT = /#{TRANSMISSION_DELIMITER}#{REG_SPACE}#{REG_SCRATCH_NAME_FORMAT}|#{REG_METHOD_END}/

    #Triggerクラス
    REG_TRIGGER_ON_DELIMITER = "<\\+"
    REG_TRIGGER_OFF_DELIMITER = TRIGGER_OFF_DELIMITER

    REG_EVENT_NAME = "\\w+"
    REG_TRIGGER_START_FORMAT = /\w+\s*(<\+|<-)\s*/
    REG_TRIGGER_FINISH_FORMAT = /#{REG_METHOD_END}/

    #Mergeクラス
    REG_MERGE_START_FORMAT = /\w+\.(merge|join)\(/


    #ブロック構文解析用
    REG_BLOCK_DO_FORMAT = /\s+do$/
    REG_BLOCK_END_FORMAT = /^end$/

    REG_BLOOM_BLOCK_FORMAT = /^bloom\s+do$/
    REG_STATE_BLOCK_FORMAT = /^state\s+do$/

    #不等号表現
    REG_SIGN = "<=|<|==|!=|>=|>"
    REG_SIGN_FORMAT = /^(#{REG_SIGN})$/
    #イベントコンディションフォーマット
    REG_EVENTS_SIGN = "=="
    REG_EVENTS_CONDITION_FORMAT = /^#{REG_EVENTS_SIGN}$/
    REG_EVENTS_CONDITION = /(?<event_name>\w+)\.(?<state>(on|off))/

    ###############################################
    #  メソッドのパース後 型変換で使用する期待型  #
    ###############################################

    # パース後の型変換で使用する期待型
    TYPE_DATANAME = "dataname"
    TYPE_SCRATCH  = TYPE_DATANAME # データ名と同様のフォーマット
    TYPE_CHANNEL  = TYPE_DATANAME # データ名と同様のフォーマット
    TYPE_INTEGER  = "integer"
    TYPE_FLOAT    = "float"
    TYPE_STRING   = "string"
    TYPE_TIME     = "time"  # "20150101T000000"などの時刻フォーマット
    TYPE_ANY      = "any"   # メソッドなど、型が存在しないもの

end
