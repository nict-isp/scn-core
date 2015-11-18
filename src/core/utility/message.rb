# -*- coding: utf-8 -*-
require_relative '../ncps/ncps'

#= メッセージクラス
# ノード間通信のメッセージを定義する。
#
#@author NICT
#
module Message

    # Supervisor宛のリクエスト
    REQUEST_SUPERVISOR       = "Supervisor"
    # ServiceManager宛のリクエスト
    REQUEST_SERVICE_MANAGER  = "ServiceManager"
    # OverlayManager宛のリクエスト
    REQUEST_OVERLAY_MANAGER  = "OverlayManager"
    # EventManager宛のリクエスト
    REQUEST_EVENT_MANAGER    = "EventManager"
    # Stats宛のリクエスト
    REQUEST_STATS            = "Stats"
    # DSNEcecutor宛のリクエスト
    REQUEST_DSN_EXECUTOR     = "DSNEcecutor"

    # Supervisor宛の伝播
    PROPAGATE_SUPERVISOR       = "Supervisor"
    # ServiceManager宛の伝播
    PROPAGATE_SERVICE_MANAGER  = "ServiceManager"
    # OverlayManager宛の伝播
    PROPAGATE_OVERLAY_MANAGER  = "OverlayManager"
    # EventManager宛の伝播
    PROPAGATE_EVENT_MANAGER    = "EventManager"
    # Stats宛の伝播
    PROPAGATE_STATS            = "Stats"
    # DSNEcecutor宛の伝播
    PROPAGATE_DSN_EXECUTOR     = "DSNEcecutor"

    # 他のノードへリクエストを送信する。（一旦Supervisorに届く）
    #
    #@param [String] dst 送信先ノードのIPアドレス
    #@param [String] message_type 送信するメッセージのタイプ
    #@param [String] method_name 依頼する処理
    #@param [Array<Object>] args 依頼する処理の引数
    #@return [Object] 依頼した処理の結果
    #
    def send_request(dst, message_type, method_name, args)
        log_trace(dst, message_type, method_name, args)
        message = encode_message([message_type, method_name, args])
        response = NCPS.request(dst, message)
        return decode_message(response)
    end

    # 他のノードへ情報を伝播する。（一旦Supervisorに届く）
    #
    #@param [String] dst 送信先ノードのIPアドレス
    #@param [String] message_type 送信するメッセージのタイプ
    #@param [String] method_name 依頼する処理
    #@param [Array<Object>] args 依頼する処理の引数
    #@return [void]
    #
    def send_propagate(dsts, message_type, method_name, args)
        log_trace(dsts, message_type, method_name, args)
        message = encode_message([message_type, method_name, args])
        NCPS.propagate(dsts, message)
    end

    private

    def encode_message(param)
        return Marshal.dump(param)
    end

    def decode_message(str)
        return Marshal.load(str)
    end

end

