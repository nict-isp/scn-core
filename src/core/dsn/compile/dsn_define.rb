# -*- coding: utf-8 -*-

module DSN

    ################################
    # Keyword of intermediate code #
    ################################
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
    # Keyword of reserved word #
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

    ##############
    # Delimiter  #
    ##############

    # Delimiter to split the syntax of the state do in the block
    STATE_SENTENCE_DELIMITER = ":"

    # Delimiter of DSN description text (line feed code)
    DSN_TEXT_DELIMITER = "\n"

    # Delimiter of the attributes of the discovery syntax
    SERVICE_ATTR_DELIMITER = "="

    # Delimiter of scratch syntax and channel syntax
    COMMUNICATION_DELIMITER = ","

    # Character to specify option of scratch and channel
    OPTION_DELIMITER = "=>"

    # Delimiter of transmission syntax
    TRANSMISSION_DELIMITER = "<~"

    # Delimiter of trigger syntax
    TRIGGER_ON_DELIMITER = "<+"
    TRIGGER_OFF_DELIMITER = "<-"

    # Delimiter of the channel name
    SERVICELINK_DATA_NAME_DELIMITER = "::"

    # Delimiter in the mehod
    METHOD_DELIMITER = ","

    ##########################################
    #  The format of the regular expression  #
    ##########################################
    REG_SPACE = "\\s*"

    REG_METHOD_NAME = "(?<method_name>\\w+)"
    CAP_INDEX_METHOD_NAME = :method_name
    CAP_METHOD_ARG       = "method_arg"
    CAP_INDEX_METHOD_ARG = :method_arg
    REG_METHOD_ARG = "(?<#{CAP_METHOD_ARG}>.*)"
    REG_METHOD_FORMAT = /^#{REG_METHOD_NAME}\(#{REG_METHOD_ARG}\)$/

    REG_SCRATCH = "(?<scratch_name>\\w+)"
    REG_PROCESSING = "(?<processing>.+)"
    REG_PROCESSING_FORMAT = /^#{REG_SCRATCH}\.#{REG_PROCESSING}$/

    REG_NOT_FORMAT = /^not\s+#{REG_METHOD_NAME}\(#{REG_METHOD_ARG}\)$/

    REG_METHOD_END = "\\)"

    REG_META_ARG = /^(\w+)\s*=\s*(\w+)$/

    REG_SERVICE_NAME = "@\\w+"
    # format for withdrawing the line that contains the name of the service (start condition)
    REG_SERVICE_START_FORMAT = /^@\w+\s*:\s*/
    # format for withdrawing the row that contains the service name (end condition)
    REG_SERVICE_FINISH_FORMAT = /#{REG_METHOD_END}/

    REG_OPTION_FORMAT = "[\\w,\\s:=\\/]+"

    REG_SCRATCH_NAME = "scratch"
    REG_CHANNEL_NAME = "channel"
    REG_SCRATCH_START_FORMAT = /^scratch\s*:\s*/
    REG_CHANNEL_START_FORMAT = /^channel\s*:\s*/
    REG_OPTION_END = "\\]"
    REG_SCRATCH_FINISH_FORMAT = /#{REG_SERVICE_NAME}/
    REG_CHANNEL_FINISH_FORMAT = /#{REG_SCRATCH_FINISH_FORMAT}/
    REG_SCRATCH_OPTION_FORMAT = /#{REG_OPTION_END}/
    REG_CHANNEL_OPTION_FORMAT = /#{REG_SCRATCH_OPTION_FORMAT}/

    # Transmission class
    REG_CHANNEL_NAME_FORMAT = "\\w+"
    REG_SCRATCH_NAME_FORMAT = REG_CHANNEL_NAME_FORMAT
    REG_TRANSMISSION_START_FORMAT = /\w+\s*<~\s/
    REG_TRANSMISSION_FINISH_FORMAT = /#{TRANSMISSION_DELIMITER}#{REG_SPACE}#{REG_SCRATCH_NAME_FORMAT}|#{REG_METHOD_END}/

    # Trigger class
    REG_TRIGGER_ON_DELIMITER = "<\\+"
    REG_TRIGGER_OFF_DELIMITER = TRIGGER_OFF_DELIMITER
    REG_EVENT_NAME = "\\w+"
    REG_TRIGGER_START_FORMAT = /\w+\s*(<\+|<-)\s*/
    REG_TRIGGER_FINISH_FORMAT = /#{REG_METHOD_END}/

    # Merge class
    REG_MERGE_START_FORMAT = /\w+\.(merge|join)\(/

    # For block parsing
    REG_BLOCK_DO_FORMAT = /\s+do$/
    REG_BLOCK_END_FORMAT = /^end$/

    REG_BLOOM_BLOCK_FORMAT = /^bloom\s+do$/
    REG_STATE_BLOCK_FORMAT = /^state\s+do$/

    # Inequality expression
    REG_SIGN = "<=|<|==|!=|>=|>"
    REG_SIGN_FORMAT = /^(#{REG_SIGN})$/

    # Format of event condition
    REG_EVENTS_SIGN = "=="
    REG_EVENTS_CONDITION_FORMAT = /^#{REG_EVENTS_SIGN}$/
    REG_EVENTS_CONDITION = /(?<event_name>\w+)\.(?<state>(on|off))/

    #####################################################################################
    # After analysis of the method, the expected type to be used in the type conversion #
    #####################################################################################

    # Expected type to be used in the type conversion after analysis
    TYPE_DATANAME = "dataname"
    TYPE_SCRATCH  = TYPE_DATANAME # The same format as the data name
    TYPE_CHANNEL  = TYPE_DATANAME # The same format as the data name
    TYPE_INTEGER  = "integer"
    TYPE_FLOAT    = "float"
    TYPE_STRING   = "string"
    TYPE_TIME     = "time"  # Time format such as "20150101T000000"
    TYPE_ANY      = "any"   # Format that type does not exist such as method

end
