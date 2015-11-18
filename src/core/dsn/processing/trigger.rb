#-*- coding: utf-8 -*-
require_relative '../compile/conditions'

#= 状態監視クラス
#
#@author NICT
#
class Events

    #@param [Hash] app_request 状態監視要求
    #@example 状態監視要求例
    #{
    #   "event_name1" => {}, # イベント情報。詳細は Event#initialize(app_request) 参照
    #   "event_name2" => {},
    #       :
    #}
    #
    def initialize(app_request)
        @events      = {}
        @app_request = {}

        update_request(app_request)
    end

    # イベント名ごとのイベントクラスを生成する。
    #
    #@param [Hash] app_request 状態監視要求
    #@return [void]
    #
    def update_request(app_request)
        if @app_request != app_request
            log_debug() { "update request = #{app_request}" }

            app_request.each do |event_name, request|
                event = @events[event_name]
                if event.nil?
                    @events[event_name] = Event.new(request)
                else
                    event.update_request(request)
                end
            end

            # 古いイベントを削除
            (@events.keys - app_request.keys).each do |event_name|
                @events.delete(event_name)
            end

            @app_request = app_request
        end
    end

    # 各イベントクラスに状態監視を依頼する
    #
    #@param [String] channel チャンネル名
    #@param [Hash<String, Object>] data 情報抽出処理後のデータ
    #@return [void]
    #
    def observe(channel, data)
        log_trace(channel, data)
        @events.each{ |event_name, event| event.observe(channel, data) }
    end

    # 発火したイベントを取得する
    #
    #@param [Hash<String, Nil>] channles 監視対象のチャンネル
    #@param [Float] time 前回からの経過時間
    #@return [Hash<String, Boolean>] 発火したイベントの、イベント名とon/offの状態（onの時、true）
    #
    def get_fire_event(channels, time)
        events = {}
        @events.each do |event_name, event|
            fire, status_on = event.fire?(channels, time)
            events[event_name] = status_on if fire
        end
        return events
    end

    # イベントの発火状態を設定する
    #
    #@param [Hash<String, Boolean>] events 発火したイベントの、イベント名とon/offの状態（onの時、true）
    #@return [void]
    #
    def set_fire_event(events)
        events.each do |event_name, status_on|
            event = @events[event_name]
            if not(event.nil?)
                event.set_status_on(status_on)
            end
        end
    end

    # イベント状態取得I/F向け
    #
    #@return [Hash] イベント状態
    #@example
    #{
    #   "event_name1" => {},     # イベント状態。詳細はEvent#to_hash()を参照
    #   "event_name2" => {},
    #       ：
    #}
    #
    def to_hash()
        return @events.inject({}){|hash, (event_name, event)| hash[event_name] = event.to_hash(); hash}
    end
end

#= イベントの状態・発火を管理するクラス
#
#@author NICT
#
class Event

    #@param [Hash] app_request 状態監視要求
    #@example 状態監視要求例
    #{
    #   "on"      => []              # イベントをonにする条件。詳細はTriggerクラス参照
    #   "off"     => []              # イベントをoffにする条件。詳細はTriggerクラス参照
    #   "channel" => "channel_name1" # 監視対象のチャンネル名
    #}
    #
    def initialize(app_request)
        @triggers    = {true => [], false => []}
        @status_on   = false
        @app_request = {}

        update_request(app_request)
    end

    # アプリケーション要求から、トリガクラスを生成する
    #
    #@param [Hash] app_request 状態監視要求
    #@return [void]
    #
    def update_request(app_request)
        log_debug() { app_request }

        if @app_request != app_request
            # 少しでも変化があれば、インスタンスを作り直す
            #
            @status_on       = app_request["state"] | false
            @triggers[true]  = app_request["off"].map{ |request| Trigger.new(request) }
            @triggers[false] = app_request["on"].map{ |request| Trigger.new(request) }

            @app_request = app_request
            reset()
        end
    end

    # 各トリガクラスにデータ受信を通知する。
    #
    #@param [String] channel チャンネル名
    #@param [Array<Hash>] data_list 受信データ
    #@return [void]
    #
    def observe(channel, data_list)
        log_trace(channel, data_list)
        @triggers[@status_on].each{ |trigger| trigger.observe(channel, data_list) }
    end

    # イベントの発火状態を取得する
    #
    #@param [Hash<String, Nil>] channles 監視対象のチャンネル
    #@param [Float] time 前回からの経過時間
    #@return [Boolean, Boolean] イベントが発火した時、true。また、イベント名とon/offの状態（onの時、true）
    #
    def fire?(channles, time)
        if @triggers[@status_on].any? { |trigger| trigger.fire?(channles, time) }
            @status_on = (not (@status_on))
            reset()

            result = true
        else
            result = false
        end
        return result, @status_on
    end

    # イベントのon/off状態を設定する。
    #
    #@param [Boolean] status_on イベント状態（onの時、true）
    #@return [void]
    #
    def set_status_on(status_on)
        if @status_on != status_on
            @status_on = status_on
            reset()
        end
    end

    # トリガの状態をリセットする。
    #
    #@return [void]
    #
    def reset()
        @triggers[@status_on].each{ |trigger| trigger.reset() }
    end

    # イベント状態取得I/F向け
    #
    #@return [True] イベントON
    #@return [False] イベントOFF
    #
    def to_hash()
        return @status_on
    end
end

#= イベントの発火を判定するクラス
#
#@author NICT
#
class Trigger

    #@param [Hash] app_request 状態監視要求
    #@example 状態監視要求例
    #{
    #   "trigger_interval" => 10,  # 発火周期。
    #   "trigger_conditions" => {   # 発火条件。詳細はConditionクラス参照
    #       "count" => [">=", 10]
    #   },
    #   "conditions" => {           # 監視対象のデータ。詳細はConditionクラス参照
    #       "rain" => [">=", 25.0]
    #   },
    #}
    #
    def initialize(app_request)
        log_debug() { app_request }

        @channel           = app_request["channel"]
        @condition         = app_request["conditions"]
        @trigger_condition = app_request["trigger_conditions"]
        @trigger_interval  = app_request["trigger_interval"]

        reset()
    end

    # 状態監視を実行する
    #
    #@param [String] channel チャンネル名
    #@param [Array<Hash>] data_list 受信データ
    #@return [void]
    #
    def observe(channel, data_list)
        if @channel == channel
            log_trace(channel, data_list)
            @count += data_list.select{|data| DSN::Conditions.ok?(@condition, data)}.size
        end
        log_debug{"count #{@count}"}
    end

    # トリガの発火状態を取得する
    #
    #@param [Hash<String, Nil>] channles 監視対象のチャンネル
    #@param [Float] time 前回からの経過時間
    #@return [Boolean] イベントが発火した時、true
    #
    def fire?(channles, time)
        result = false
        if channles.include?(@channel)
            @time += time
            if @time >= @trigger_interval
                result = DSN::Conditions.ok?(@trigger_condition, {"count" => @count})
                reset()
            end
        else
            reset()
        end
        return result
    end

    # トリガの状態をリセットする。
    #
    #@return [void]
    #
    def reset()
        @count = 0
        @time = 0
    end
end

