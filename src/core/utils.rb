# -*- coding: utf-8 -*-
require 'logger'
require 'ipaddr'
require 'json'
require 'time'

require_relative './errors'
load './config.rb'

# オブジェクトをディープコピーする
#
#@param obj ディープコピーするオブジェクト
#@return ディープコピーしたオブジェクト
#
def deep_copy(obj)
    return Marshal.load(Marshal.dump(obj))
end

DATA_TIME_FOMAT = "%Y-%m-%dT%H%M%S"

# システム秒を時刻文字列に変換する
#
#@param [Integer] システム秒
#@return [String] 時刻文字列
#
def sec_to_time(second)
    return Time.at(second).strftime(DATA_TIME_FOMAT)
end

# 時刻文字列をシステム秒に変換する
#
#@param [String] date 時刻文字列
#@return [Integer] システム秒
#
def time_to_sec(date)
    return Time.parse(date).to_i
end

# Fatalログ出力メソッド
#
#@param [String] message 出力メッセージ
#@return [void]
#
def log_fatal(message)
    $logger.fatal(message)
end

# Errorログ出力メソッド
#
#@param [String] message 出力メッセージ
#@return [void]
#
def log_error(message, error=nil)
    if not error.nil?()
        message << "\n#{error.inspect()}\n\t"
        message << error.backtrace().join("\n\t")
    end
    $logger.error(addruninfo(message))
end

# Warningログ出力メソッド
#
#@param [String] message 出力メッセージ
#@return [void]
#
def log_warn(message)
    $logger.warn(message)
end

# Infoログ出力メソッド
#
#@param [String] message 出力メッセージ
#@return [void]
#
def log_info(message)
    $logger.info(message)
end

# Debugログ出力メソッド
# 文字列生成コストによる性能劣化を防止するため、ログ出力文字列はブロック文で受け取る
#
#@param [String] message 出力メッセージ
#@return [void]
#
def log_debug()
    $logger.debug(addruninfo(yield)) if $logger.debug?()
end

# Traceログ出力メソッド
#
#@param [Array<Object>] args 呼び出し元の引数リスト
#@return [void]
#
def log_trace(*args)
    $logger.debug(addruninfo(args.map{ |arg| arg.to_s }.join(", "))) if $trace && $logger.debug?()
end

# Timeログ出力メソッド
# 性能測定に用いる
#
#@param [String] message 出力メッセージ
#@return [void]
#
def log_time(message=nil)
    $logger.info("TIME:" << addruninfo(message)) if $benchmark
end

# メッセージにプログラム実行情報を追加する。
#
#@param [String] message 出力メッセージ
#@return [String] プログラムの実行情報を追加した文字列
#
def addruninfo(message)
    return "[#{self.class.name}] #{caller[1]} : #{message}"
end

# IPアドレスのフォーマットをチェックする。
#
#@param [String] ipaddress IPアドレス
#@return [True] IPアドレスの指定が正しい,
#@return [False] IPアドレスの指定が誤り
#
def set_ipaddress_ok?(ipaddress)
    log_trace(ipaddress)

    # サブネットの指1G定有無チェック
    if /(.+)\/.+/ =~ ipaddress
        begin
            # IPアドレスの体裁チェック
            $ip = $1
            log_info("ip #{$ip}")
            IPAddr.new(ipaddress).to_s
            result = true
        rescue
            result = false
        end
    else
        result = false
    end

    return result
end

#@param [String] ipaddress IPアドレス
#@return [True] このノード のIPアドレスである
#@return [False] このノードのIPアドレスではない
#
def current_node?(ipaddress)
    return ipaddress == $ip
end

# JSON化した際の、オブジェクトのデータサイズを再帰的に計算する
#
#@param [Object] o 計算対象のオブジェクト
#@return [Integer] データサイズ（byte）
#
def calc_size(o)
    if o.instance_of? Hash
        size = 2
        sep = 0
        o.each do |k, v|
            size += calc_size(k) + 2 + sep  #:
            if v.nil?
                size += 4   #null
            else
                size += calc_size(v)
            end
            sep = 2     #,
        end
        return size

    elsif o.instance_of? Array
        size = 2    #[]
        sep = 0
        o.each do |v|
            size += calc_size(v) + sep
            sep = 2     #,
        end
        return size

    elsif o.instance_of? String
        return o.length + 2   #""

    else
        return o.to_s.length
    end
end
