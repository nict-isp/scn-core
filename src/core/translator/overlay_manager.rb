# -*- coding: utf-8 -*-
require 'forwardable'

require_relative '../utils'
require_relative '../utility/message'
require_relative './stats'
require_relative './overlay'
require_relative '../dsn/event_manager'
require_relative '../dsn/processing_manager'

#= オーバーレイ管理クラス
# オーバーレイへの操作、情報の取得を行う。
# オーバーレイの状態が変更された際には、構成するノードへ情報を伝播し
# データの送受信や中間処理が他ノードでも正しく行われるようにする。
#
#@author NICT
#
class OverlayManager
    include Message

    #@param [String] middleware_id ミドルウェアID
    #
    def initialize(middleware_id)
        @middleware_id = middleware_id
        @overlay_list  = SyncHash.new()
        @overlay_count = 0
        @lock_list     = {}
    end

    #@param [String] overlay_id オーバーレイID
    #@return [Overlay] オーバーレイ
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #@note 取得したオーバーレイを直接操作しないこと。（情報が伝搬されないため）
    #
    def get_overlay(overlay_id)
        log_trace(overlay_id)
        overlay = @overlay_list[overlay_id]
        if overlay.nil?
            raise InvalidIDError, overlay_id
        end
        return overlay
    end

    # オーバーレイを作成する。
    #
    #@param [String] overlay_name オーバーレイ名
    #@param [Integer] liten_port 動作ログ待受けポート
    #@return [String]  オーバーレイID
    #
    def create_overlay(overlay_name, liten_port)
        overlay_id  = generate_overlay_id()
        @overlay_list[overlay_id] = Overlay.new(overlay_id, overlay_name, @middleware_id, $ip, liten_port)
        return overlay_id
    end

    #@param [String] overlay_id オーバーレイID
    #@return [void]
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #
    def delete_overlay(overlay_id)
        overlay = @overlay_list.delete(overlay_id)
        dsts    = overlay.get_nodes()

        propagate(dsts, overlay.id, nil)    # 誤送信を防ぐため先に伝播
        overlay.delete()
    end

    #@param [String] overlay_id オーバーレイID
    #@param [Hash] trigger トリガ情報
    #@return [void]
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #
    def set_trigger(overlay_id, trigger)
        log_trace(overlay_id, trigger)
        operate_overlay(overlay_id){ |overlay| overlay.set_trigger(deep_copy(trigger)) }
    end

    #@param [String] overlay_id オーバーレイID
    #@param [Array<Hash>] merge マージ情報
    #@return [void]
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #
    def set_merge(overlay_id, merge)
        log_trace(overlay_id, merge)
        operate_overlay(overlay_id){ |overlay| overlay.set_merge(deep_copy(merge)) }
    end

    #@param [String] overlay_id オーバーレイID
    #@param [ChannelRequest] channel_req チャネル要求
    #@return [String] チャネルID
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #
    def create_channel(overlay_id, channel_req)
        log_trace(overlay_id, channel_req)
        return operate_overlay(overlay_id){ |overlay| overlay.create_channel(channel_req) }
    end

    #@param [String] channel_id チャネルID
    #@param [ChannelRequest] channel_req チャネル要求
    #@return [void]
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #
    def update_channel(channel_id, channel_req = nil)
        log_trace(channel_id, channel_req)
        operate_channel(channel_id){ |overlay| overlay.update_channel(channel_id, channel_req) }
    end

    #@param [String] channel_id チャネルID
    #@return [void]
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #
    def delete_channel(channel_id)
        log_trace(channel_id)
        operate_channel(channel_id){ |overlay| overlay.delete_channel(channel_id) }
    end

    #@param [String] channel_id チャネルID
    #@return [void]
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #
    def activate_channel(channel_id)
        log_trace(channel_id)
        operate_channel(channel_id){ |overlay| overlay.activate_channel(channel_id) }
    end

    #@param [String] channel_id チャネルID
    #@return [void]
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #
    def inactivate_channel(channel_id)
        log_trace(channel_id)
        operate_channel(channel_id){ |overlay| overlay.inactivate_channel(channel_id) }
    end

    #@param [String] channel_id チャネルID
    #@return [Channel] チャネル
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #
    def get_channel(channel_id)
        overlay = get_overlay_by_channel_id(channel_id)
        return overlay.get_channel(channel_id)
    end

    #@param [String] service_id サービスID
    #@return [Array<Overlay>] サービスを含むオーバーレイ
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #
    def get_overlays_by_service_id(service_id)
        log_trace(service_id)
        return @overlay_list.values().select{ |overlay| overlay.include_service?(service_id) }
    end

    #@param [String] service_id サービスID
    #@return [Array<Overlay>] サービスを含むオーバーレイ
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #
    def update_overlays_by_service(service_id, service)
        get_overlays_by_service_id(service_id).each do |overlay|
            dsts = overlay.get_nodes()
            if overlay.update_service(service_id, service)
                propagate(dsts, overlay.id, overlay)
            end
        end
    end

    # オーバーレイの実行ログを送信する
    #
    #@paran [String] overlay_id 宛先のオーバーレイID
    #@param [Hash] message メッセージ
    #@return [void]
    #
    def send_message(overlay_id, message)
        overlay = get_overlay(overlay_id)

        if current_node?(overlay.supervisor)
            overlay.send_message(message)
        else
            send_propagate([overlay.supervisor], PROPAGATE_OVERLAY_MANAGER, "send_message", [overlay_id, message])
        end
    end

    private

    # #{ミドルウェアID}_#{オーバーレイID}
    #
    def generate_overlay_id()
        @overlay_count += 1
        overlay_id = @middleware_id + '_' + @overlay_count.to_s

        return overlay_id
    end

    def get_overlay_by_channel_id(channel_id)
        log_trace(channel_id)
        id, overlay = @overlay_list.find{ |id, overlay| overlay.include_channel?(channel_id) }
        if overlay.nil?
            raise InvalidIDError, channel_id
        end
        return overlay
    end

    # オーバーレイに対する操作のテンプレート
    #
    def operate_overlay(overlay_id)
        overlay = get_overlay(overlay_id)
        dsts    = overlay.get_nodes()

        #TODO 毎回伝播だと、1つのオーバーレイが大幅に変わる際の通信が無駄
        result = yield(overlay)
        propagate(dsts, overlay.id, overlay)

        return result
    end

    # オーバーレイ情報を伝播する
    # チャネルに対する操作のテンプレート
    #
    def operate_channel(channel_id)
        overlay = get_overlay_by_channel_id(channel_id)
        dsts    = overlay.get_nodes()

        #TODO 毎回伝播だと、1つのオーバーレイが大幅に変わる際の通信が無駄
        result = yield(overlay)
        propagate(dsts, overlay.id, overlay)

        return result
    end

    # オーバーレイ情報を伝播する
    #
    def propagate(dsts, overlay_id, overlay)
        log_trace(dsts, overlay_id, overlay)
        dsts |= overlay.get_nodes() unless overlay.nil?
        dsts.delete($ip)
        send_propagate(dsts, PROPAGATE_OVERLAY_MANAGER, "set_overlay", [overlay_id, overlay])
        set_overlay(overlay_id, overlay)

        Stats.set_overlay(overlay_id, overlay)
    end

    # ノード間通信を含むシーケンスを統一するための共通の受け口
    #
    def set_overlay(overlay_id, overlay)
        log_trace(overlay_id, overlay)
        @overlay_list[overlay_id] = overlay

        # 自ノードの情報もこのシーケンスで反映させる。
        ProcessingManager.set_overlay(overlay_id, overlay)
        EventManager.set_overlay(overlay_id, overlay)
    end
end
