# -*- coding: utf-8 -*-:
require 'singleton'
require 'forwardable'
require 'json'

require_relative './node_resource'
require_relative '../utility/collector'
require_relative '../utility/sync'

#= 統計情報管理クラス
# 以下の統計情報の収集と取得をお管理する。
# - ノードの統計情報
# - チャネル、パスの統計情報（予定）
# - フロー、トポロジーの統計情報（予定）
#
#@author NICT
#
class Stats
    include Singleton

    def initialize()
        @interval      = nil
        @node_resource = nil
        @path_stats    = SyncHash.new{|h, k| h[k] = [nil, 0, 0, 0]}
    end

    # 周期処理による統計情報の収集を開始する。
    #
    #@param [Integer] 収集周期
    #
    def start(interval)
        if @interval.nil?
            Thread.new do
                sleep 1
                supervise()
            end
        end
        @interval = interval
    end

    # オーバーレイの情報を収集する。
    #
    #@param [String] overlay_id オーバーレイID
    #@param [Ovelray] overlay 変更のあったオーバーレイ
    #@return [void]
    #
    def set_overlay(overlay_id, overlay)
        EventCollector.statistics_overlay(overlay_id, overlay)
        if overlay.nil?
            #TODO 削除メッセージ
        else
            ApplicationRPCClient.receive_message(overlay_id, JSON.generate(overlay.to_message), overlay.liten_port)
        end
    end

    # データの送信情報を収集する。
    #
    #@param [Path] path データを送信したパス
    #@param [Integer] data_size サービスからの送信データサイズ
    #@param [Integer] processed_size 中間処理後の送信データサイズ
    #@return [void]
    #
    def send_data(path, data_size, processed_size)
        log_trace(path, data_size, processed_size)
        @path_stats[path.id][0] = path
        @path_stats[path.id][1] += data_size
        @path_stats[path.id][2] += processed_size
    end

    # データの受信情報を収集する。
    #
    #@param [Path] path データを受信したパス
    #@param [Integer] receive_size 中間処理後の受信データサイズ
    #@return [void]
    #
    def receive_data(path, receive_size)
        log_trace(path, receive_size)
        @path_stats[path.id][0] = path
        @path_stats[path.id][3] += receive_size
    end

    private

    def supervise()
        loop do
            log_trace()
            begin
                # 資源情報を更新する。
                @node_resource = NodeResourceCollector.update()

                # 統計情報を送信する。
                EventCollector.statistics_node(@node_resource)
                @path_stats.each do |path_id, stats|
                    path, data_size, processed_size, receive_size = stats
                    log_trace(path_id, path, data_size, processed_size, receive_size)

                    EventCollector.statistics_throughput(path_id, data_size, processed_size, receive_size)
                    EventCollector.receive(path, receive_size) if receive_size > 0
                end
                @path_stats.clear

            rescue
                log_error("", $!)
            end
            sleep @interval
        end
    end

    # インスタンスメソッドをクラスに委譲
    class << self
        extend Forwardable
        def_delegators :instance, *Stats.instance_methods(false)
    end
end
