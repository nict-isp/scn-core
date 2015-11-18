require 'singleton'

require_relative './processing/trigger'
require_relative '../utility/message'

#= イベント管理クラス
#
#@author NICT
#
class EventManager
    include Singleton
    include Message

    attr_reader :triggers

    def initialize
        log_trace()
        @triggers = {}
        @overlays = {}
    end

    # 初期設定
    #
    #@param [Integer] interval イベント監視の動作周期
    #
    def setup(interval)
        @interval = interval

        supervise()
    end

    # 状態監視情報より、状態監視の中間処理を生成・更新する
    #
    #@param [String] overlay_id オーバーレイID
    #@param [Hash] app_request 状態監視情報
    #@return [void]
    #
    def set_overlay(overlay_id, overlay)
        log_trace(overlay_id, overlay)
        @overlays[overlay_id] = overlay

        if overlay.nil?
            @triggers[overlay_id] = nil
        else
            trigger = @triggers[overlay_id]
            if trigger.nil?
                @triggers[overlay_id] = Events.new(overlay.trigger)
            else
                trigger.update_request(overlay.trigger)
            end
        end
        log_debug {"#{@triggers}"}
    end

    # 状態監視を実行する
    #
    #@param [Array<Hash>] data 受信データ
    #@return [Array<Hash>] 受信時処理を実行した受信データ
    #
    def observe(overlay_id, channel_name, data)
        log_trace(overlay_id, channel_name, data)
        trigger = @triggers[overlay_id]
        unless trigger.nil?
            if M2MFormat.formatted?(data)
                data_list = M2MFormat.get_values(data)
            else
                data_list = data
            end
            trigger.observe(channel_name, data_list)
        end
    end

    private

    def supervise
        Thread.new do
            loop do
                log_trace
                begin
                    @triggers.each do |id, events|
                        overlay = @overlays[id]
                        unless overlay.nil?
                            channels = overlay.get_current_channels()
                            log_trace(channels)
                            events = events.get_fire_event(channels, @interval)
                            log_trace(overlay, events)
                            next if events.empty?

                            send_propagate([overlay.supervisor], PROPAGATE_DSN_EXECUTOR, "update_overlay", [id, events])
                        end
                    end
                rescue
                    log_error("supervise error.", $!)
                end
                sleep @interval
            end
        end
    end

    # インスタンスメソッドをクラスに委譲
    class << self
        extend Forwardable
        def_delegators :instance, *EventManager.instance_methods(false)
    end
end
