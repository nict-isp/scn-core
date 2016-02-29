# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require 'fluent-logger'
require 'date'
require 'singleton'
require 'forwardable'

require_relative 'sync'
require_relative '../utils'
require_relative '../translator/supervisor'

#= イベント収集クラス
# SCN-Visualizer向けのイベントログをFluent-dで収集する。
# また、そのログファイルを作成する。
#
#@author NICT
#
class EventCollector
    include Singleton

    # グラフ出力用タグ
    TAG_STAT    = "scnm.stat"
    # ネットワーク表示用タグ
    TAG_OVERLAY = "scnm.redis"

    def initialize()
        @error = false
        @paths = SyncHash.new()
        @flows = SyncHash.new() {|h, k| h[k] = []}
    end

    # Fluentサーバーへ接続する。
    #
    def setup()
        fluent_ip_address = $config[:fluent_ip_address]
        fluent_port       = $config[:fluent_port]
        logging_dir       = $config[:event_logging_dir]

        Fluent::Logger::FluentLogger.open(nil, :host => fluent_ip_address, :port => fluent_port)  if $config[:event_collecting]
        @log = LogFile.new(logging_dir) if $config[:event_logging]
    end

    # 統計情報を送信する（ノードリソース）
    #
    #@param [NodeResource] resource ノードリソース情報
    #@return [void]
    #
    def statistics_node(resource)
        return unless $config[:event_collecting]
        post(TAG_STAT, {"node" => {
            $config[:hostname] => resource
        }})
    end

    # 統計情報を送信する（オーバーレイ）
    #
    #@param [String] overlay_id 更新したオーバーレイのID
    #@param [Overlay] overlay 更新したオーバーレイの情報
    #@return [void]
    #
    def statistics_overlay(overlay_id, overlay)
        return unless $config[:event_collecting]
        return if overlay.nil?  #TODO 削除メッセージの追加

        paths = overlay.channels.map{|id, channel| channel.paths.map{|path| path.id }}.flatten
        post(TAG_STAT, {"overlay" => {
            overlay.name => {
            "name" => overlay.name,
            "service_links" => paths
            }
        }})
    end

    # 統計情報を送信する（スループット）
    #
    #@param [String] path_id 送信パスID
    #@param [Integer] data_size 送信データサイズ（フィルタ前）
    #@param [Integer] processed_size 送信データサイズ（フィルタ後）
    #@param [Integer] receive_size 受信データサイズ
    #@return [void]
    #
    def statistics_throughput(path_id, data_size, processed_size, receive_size)
        return unless $config[:event_collecting]
        log_trace(path_id, data_size, processed_size, receive_size)
        post(TAG_STAT, {
            "send"     => {path_id => data_size},
            "filtered" => {path_id => processed_size},
            "received" => {path_id => receive_size},
        })
    end

    # サービス登録イベントを送信する
    #
    #@param [Service] service 登録されたサービス
    #@return [void]
    #
    def join_service(service)
        return unless $config[:event_collecting]
        publish("overlay", {
            "Rule"  => "r1",
            "Src"   => service.name,
            "Code"  => "INSERT_SERVICE : #{service.name}",
        })
        publish("servicelocation", {
            "service_key"  => service.name,
            "service_name" => service.name,
            "node_ip"      => service.ip,
            "mode"         => "ADD",
        })
    end

    # サービス検索イベントを送信する
    #
    #@param [String] query 検索クエリ
    #@param [Array<Service>] services 検索結果
    #@return [void]
    #
    def discovery_service(query, services)
        return unless $config[:event_collecting]
        publish_message("DISCOVERY : #{query}")
        publish_message("DISCOVERY_RESPONSE : [#{services.map{|service| service.name}.join(", ")}]")
    end

    # サービス更新イベントを送信する
    #
    #@param [String] service_id サービスID
    #@param [String] code イベントメッセージ
    #@return [void]
    #
    def update_service(service)
        return unless $config[:event_collecting]
        publish_message("UPDATE_SERVICE : #{service.name}")
    end

    # サービス離脱イベントを送信する（未対応）
    #
    #@param [String] service_id サービスID
    #@param [String] host サービスの存在するホスト名
    #@param [String] code イベントメッセージ
    #@return [void]
    #
    def leave_service(service)
        return unless $config[:event_collecting]
        publish("overlay", {
            "Rule"  => "r7",
            "Src"   => service.name,
            "Code"  => "LEAVE_SERVICE : #{service.name}",
        })
        publish("servicelocation", {
            "service_key"  => service.name,
            "service_name" => service.name,
            "node_ip"      => service.ip,
            "mode"         => "DEL",
        })
    end

    # 統計情報出力用にパスの情報を記録する
    #
    #@param [Path] path 物理パス
    #@return [void]
    #
    def set_path(path)
        return unless $config[:event_collecting]
        @paths[path.id] = path
    end

    #@param [Path] path 物理パス
    #@return [void]
    #
    def activate_path(path)
        return unless $config[:event_collecting]
        # SCN-Visualizerにはパスの活性・不活性の概念がないため、リンク生成イベントを送る
        @flows[path.id].each{|flow_id| create_service_link(path.id, flow_id) }
    end

    #@param [Path] path 物理パス
    #@return [void]
    #
    def inactivate_path(path)
        return unless $config[:event_collecting]
        # SCN-Visualizerにはパスの活性・不活性の概念がないため、リンク削除イベントを送る
        @flows[path.id].each{|flow_id| delete_service_link(path.id, flow_id) }
    end

    #@param [String] path_id 論理パスID
    #@param [String] flow_id 物理パスID
    #@return [void]
    #
    def create_flow(path_id, flow_id)
        return unless $config[:event_collecting]
        @flows[path_id] << flow_id
        create_service_link(path_id, flow_id)
    end

    #@param [String] path_id 論理パスID
    #@param [String] flow_id 物理パスID
    #@return [void]
    #
    def update_flow(path_id, flow_id)
        return unless $config[:event_collecting]
        update_service_link(path_id, flow_id)
    end

    #@param [String] path_id 論理パスID
    #@param [String] flow_id 物理パスID
    #@return [void]
    #
    def delete_flow(path_id, flow_id)
        return unless $config[:event_collecting]
        @flows[path_id].delete(flow_id)
        delete_service_link(path_id, flow_id)
    end

    #@param [Path] path 物理パス
    #@param [Integer] data_size 受信サイズ
    #@return [void]
    #
    def receive(path, data_size)
        return unless $config[:event_collecting]
        receive_data(path, data_size)
    end

    private

    # リンク作成イベントを送信する
    #
    def create_service_link(path_id, flow_id)
        overlay = get_overlay(path_id) 
        path    = get_path(path_id)

        src_service = path.src_service
        dst_service = path.dst_service
        code = "CREATE_SERVICE_LINK : #{overlay.name}(#{src_service.name} -> #{dst_service.name})"
        publish_rule_event("r2", "add", overlay, flow_id, src_service, dst_service, code)
        publish_link_event("cr", overlay, flow_id, src_service, dst_service, nil)
    rescue InvalidIDError
        log_error("Invalid path ID #{path_id}", $!)
    end

    # リンク更新イベントを送信する
    #
    def update_service_link(path_id, flow_id)
        overlay = get_overlay(path_id) 
        path    = get_path(path_id)

        src_service = path.src_service
        dst_service = path.dst_service
        code = "UPDATE_SERVICE_LINK : #{overlay.name}(#{src_service.name} -> #{dst_service.name})"
        publish_rule_event("dummy", "seq", overlay, flow_id, src_service, dst_service, code)
    rescue InvalidIDError
        log_error("Invalid path ID #{path_id}", $!)
    end

    # リンク削除イベントを送信する
    #
    def delete_service_link(path_id, flow_id)
        overlay = get_overlay(path_id) 
        path    = get_path(path_id)

        src_service = path.src_service
        dst_service = path.dst_service
        code = "DELETE_SERVICE_LINK : #{overlay.name}(#{src_service.name} -> #{dst_service.name})"
        publish_rule_event("r3", "seq", overlay, flow_id, src_service, dst_service, code)
        publish_link_event("dr", overlay, flow_id, src_service, dst_service, nil)
    rescue InvalidIDError
        log_error("Invalid path ID #{path_id}", $!)
    end

    # データ受信イベントを送信する
    #
    def receive_data(path, data_size)
        overlay = get_overlay(path.id) 

        src_service = path.src_service
        dst_service = path.dst_service
        code = "DATA_RECEIVE : #{overlay.name}(#{src_service.name} -> #{dst_service.name}), #{data_size}[byte]"
        publish_rule_event("r0", "recv", overlay, nil, src_service, dst_service, code)
    rescue InvalidIDError
        log_error("Invalid path ID #{path.id}", $!)
    end

    def get_overlay(path_id)
        log_trace(path_id)
        if path_id =~ /^([^_]+_[^_]+)_[^_]+_[^_]+$/
            return Supervisor.get_overlay($1)
        else
            raise InvalidIDError, path_id
        end
    end

    def get_path(path_id)
        if @paths.include?(path_id)
            return @paths[path_id]
        else
            raise InvalidIDError, path_id
        end
    end

    def post(channel, payload)
        Fluent::Logger.post(channel, payload) if $config[:event_collecting]
    rescue
        log_error("Unable to publish.", $!)
    end

    # メッセージのみのイベント
    #
    def publish_message(code)
        publish("overlay", {
            "Rule"  => "dummy",
            "Src"   => "dummy",
            "Code"  => code,
        })
    end

    # サービス連携に関連するイベント
    #
    def publish_rule_event(rule, type, overlay, flow_id, src_service, dst_service, code)
        src_flow, dst_flow = flow_id.split("_bi_") unless flow_id.nil?
        publish("overlay", {
            "Rule"  => rule,
            "Uid"   => overlay.name,
            "Src"   => src_service.name,
            "Dst"   => dst_service.name,
            "Code"  => code,
            "Value" => {
            "#{type}.no"  => flow_id,
            "#{type}.uid" => overlay.name,
            "#{type}.src" => src_service.name,
            "#{type}.dst" => dst_service.name,
            "src.path"    => src_flow,
            "dst.path"    => dst_flow,
            },
        })
    end

    # リンクの生成削除に関するイベント
    #
    def publish_link_event(rule, overlay, flow_id, src_service, dst_service, code)
        src_flow, dst_flow = flow_id.split("_bi_") unless flow_id.nil?
        publish("overlay", {
            "Rule"  => rule,
            "Uid"   => overlay.name,
            "Src"   => src_service.name,
            "Dst"   => dst_service.name,
            "Code"  => code,
            "Value" => {
            "src.path" => src_flow,
            "dst.path" => dst_flow,
            },
        })
    end

    # イベントを送信する
    #
    def publish(channel, payload)
        Thread.new do
            begin
                payload["Time"], payload["Timestamp"] = now_time()
                data = {"type" => "publish", "key" => channel, "data"=> payload}
                Fluent::Logger.post(TAG_OVERLAY, data) if $config[:event_collecting]
                @log.write(JSON.dump(data)) if $config[:event_logging]

                @error = false
            rescue
                log_error("Unable to publish.", $!) if not @error
                @error = true
            end
        end
    end

    LOG_TIME_FORMAT = "%s.%03d"
    LOG_TIME_FORMAT_HMS = "%H:%M:%S"

    # 現在時刻を取得する。
    #
    #@return [String] 現在時刻(HH:MM:SS.mm)
    #
    def now_time()
        now = Time.now
        return sprintf(LOG_TIME_FORMAT, now.strftime(LOG_TIME_FORMAT_HMS) , now.usec / 1000), now.usec / 1000
    end

    # インスタンスメソッドをクラスに委譲
    class << self
        extend Forwardable
        def_delegators :instance, *EventCollector.instance_methods(false)
    end
end

#= ログファイルクラス
# タイムスタンプ付きでハッシュデータを書き出す。
# 一定件数でログのローテートを行なう。
# リプレイツールで使用する。
#
#@author NICT
#
class LogFile

    #@param [Stirng] name ログファイルに付与する名前
    #@param [Integer] linemax 1ファイルあたりの最大データ件数
    #
    def initialize(name, linemax = 10000)
        @name    = name
        @fp      = nil
        @linemax = linemax
        open()
    end

    # データを書き込む。
    # データ件数が一定に達した時は、ログのローテートを行なう。
    #
    #@param [Hash] data 書き込むデータ
    #@return [void]
    #
    def write(data)
        if @count >= @linemax
            open()
        end

        @fp.write("#{strftime()} #{data}\n")
        @count += 1
    end

    private

    def open()
        if not @fp.nil?()
            @fp.close()
        end
        @fp = File.open("#{@name}_#{strftime("%s-%s-%06d", "%Y%m%d", "%H%M%S")}.log", "w")
        @count = 0
    end

    def strftime(datetime = "%sT%s,%06d", date = "%Y-%m-%d", time = "%H:%M:%S")
        return sprintf(datetime, Date.today.strftime(date), Time.now.strftime(time), Time.now.usec)
    end
end

