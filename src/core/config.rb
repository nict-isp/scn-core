# -*- coding: utf-8 -*-

########
# main #
########
# RPC初期受信用ポート
@rpc_initial_rx_port = 10000

# RPC受信用ポート
@rpc_rx_port = 21001

# RPC送信用基底ポート
@rpc_tx_port_base = 22000

# RPC送信IPアドレス
@rpc_ip_address = "127.0.0.1"

##########
# Logger #
##########
$log_file          = ENV['HOME'] + "/log/scn.log"
#$logger            = Logger.new(STDOUT)
$logger            = Logger.new($log_file, 'daily', File::WRONLY | File::CREAT)
$logger.formatter  = Class.new(Logger::Formatter) {

    def initialize(*args)
        super

        @log_format  = "[%s.%03d |#{`hostname`.strip}] %5s -- %s: %s\n"
        @date_format = "%Y-%m-%d %H:%M:%S"
    end

    def call(severity, time, progname, msg)
        @log_format % [time.strftime(@date_format), time.usec / 1000, severity, progname, msg2str(msg)]
    end
}.new

# FATAL | ERROR | WARN | INFO | DEBUG
$logger.level      = Logger::DEBUG
$benchmark         = false
$trace             = true

###################
# EventCollector ##
###################
@hostname = `hostname`.strip
# true でVisualizer（Redis）にイベントを通知
@event_collecting  = true

# true でログファイルにイベントを記録
@event_logging     = true
@event_logging_dir = ENV['HOME'] + "/log/redis_#{@hostname}"

# fluend設定
@fluent_port       = 24224
@fluent_ip_address = "172.18.100.3"

##################
# DSNExecutor #
##################
# DSN自動実行の動作周期[s]
@dsn_auto_execute_interval = 60
# DSNイベント監視の動作周期[s]
@dsn_observe_interval = 5

# 自動実行されるDSNファイルの格納ディレクトリ
@dsn_store_path = ENV['HOME'] + "/dsn"
# 自動実行されるDSNファイルの拡張子
@dsn_file_ext = ".dsn"
# DSN実行ログの格納ディレクトリ
@dsn_log_store_path = ENV['HOME'] + "/dsn/log"
# DSN実行ログファイルの拡張子
@dsn_log_file_ext = ".log"

##############
# Translator #
##############
# ノード情報の送信周期[s]
@statistics_interval = 30

###############
# NCPS Client #
###############
# ネットワーク種別
$ncps_network = "OpenFlow"
#$ncps_network = "TCP"

# データメッセージ用基底ポート
@data_port_base = 11001

# データメッセージ用ポートの上限
@data_port_max = 20000

# コントロールメッセージ用ポート
@ctrl_port = 20001

# リクエストを一斉送信する最大数
@request_slice = 100

# HeartBeatパケットの送信有無
@use_heart_beat = false

# HeartBeatパケットの送信周期[s]
@heart_beat_interval = 5

# NCPS Serverとの通信用ポート
@cmd_port = 31001

$config = Hash.new
instance_variables.each {|name|
    $config[name[1..-1].to_sym] = instance_variable_get(name)
}

