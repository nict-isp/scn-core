# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative '../utils'

#= NCPSのインターフェース
#
# 以下のインターフェースを提供する。
# - SCN参加
# - SCN離脱
# - サービス参加
# - サービス更新
# - サービス離脱
# - サービス検索
# - パス作成
# - パス更新
# - パス削除
# - データ送信
# - データ送信（マルチキャスト）
# - ルール伝送
#
#@author NICT
#
class NCPSInterface

    # サーバーを起動し、SCN空間へ参加する。
    #
    #@return [Array<String>] ミドルウェアIDとサービス管理ノードのアドレス
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #@raise [InternalServerError] NCPSサーバー内部でエラーが発生した場合
    #@raise [Timeout::Error] 要求がタイムアウトした場合
    #
    def start()
        raise NotImplementedError
    end

    # サーバーを停止し、SCN空間から離脱する。
    #
    #@return [void]
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #@raise [IInternalServerError] NCPSサーバー内部でエラーが発生した場合
    #@raise [Timeout::Error] 要求がタイムアウトした場合
    #
    def stop()
        raise NotImplementedError
    end

    # パスに対するノード間のデータ送信経路（フロー）を作成する。
    #
    # 作成したフローがユーザ要求を満たせなくなった時、
    # PUSHメッセージにてコールバックする。
    #
    #@param [String] src データの送信ノード
    #@param [String] dst データの受信ノード
    #@param [Hash] condition ユーザ要求（QoS）
    #@return [void]
    #@raise [NetworkError] ネットワーク構成に障害がある場合
    #@raise [InternalServerError] NCPSサーバー内部でエラーが発生した場合
    #@raise [Timeout::Error] 要求がタイムアウトした場合
    #
    def create_flow(src, dst, condition = {})
        raise NotImplementedError
    end

    # パスに対するフローのユーザー要求を更新する。
    #
    #@param [String] path_id フローを作成済みのパスID
    #@param [Hash] condition ユーザ要求（QoS）
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #@raise [InternalServerError] NCPSサーバー内部でエラーが発生した場合
    #@raise [Timeout::Error] 要求がタイムアウトした場合
    #@return [void]
    #
    def update_flow(path_id, condition)
        raise NotImplementedError
    end

    # パスに対するフローをすべて削除する
    # 送信元ノードを指定した場合は、当該フローのみを削除する
    #
    #@param [String] path_id 作成済みのパスID
    #@param [String] src データの送信ノード（任意）
    #@return [void]
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #@raise [InternalServerError] NCPSサーバー内部でエラーが発生した場合
    #@raise [Timeout::Error] 要求がタイムアウトした場合
    #
    def delete_flow(path_id, src = nil)
        raise NotImplementedError
    end

    # パスに対するフローを通してデータを送信する。
    #
    #@param [String] path_id 作成済みのパスID
    #@param [String/Hash] data 送信データ（JSON）
    #@param [Integer] data_size 送信データサイズ
    #@param [Boolean] sync Trueの時、送信の完了を待ち合せる
    #@raise [Timeout::Error] 要求がタイムアウトした場合
    #@return [void]
    #
    def send_data(path_id, data, data_size, sync = false)
        raise NotImplementedError
    end

    # パスに対するを通してデータを送信されたメッセージを受け取る
    #
    #@param [String] path_id 作成済みのパスID
    #@param [String/Hash] data 受信データ（JSON）
    #@param [Integer] data_size 受信データサイズ
    #@return [void]
    #
    def receive_data(path_id, data, data_size)
        log_trace(path_id, data, data_size)
        Supervisor.receive_data(path_id, data, data_size)
    end

    # 他ノードへリクエストを送信する。（同期通信）
    #
    #@param [String] message リクエスト
    #@param [String] ｄｓｔ リクエストの送信先
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #@raise [Timeout::Error] 要求がタイムアウトした場合
    #@return [String] レスポンス
    #
    def request(dst, message)
        raise NotImplementedError
    end

    # 他ノードからのリクエストに返答する。
    #
    #@param [String] message リクエスト
    #@param [String] src リクエストの送信元
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #@raise [Timeout::Error] 要求がタイムアウトした場合
    #@return [void]
    #
    def receive_request(message)
        Supervisor.receive_request(message)
    end

    # 他ノードへメッセージを伝送する（非同期通信）
    #
    #@param [String] message 送信データ（JSON）
    #@param [Array[String]] services メッセージの伝送先
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #@raise [Timeout::Error] 要求がタイムアウトした場合
    #@return [void]
    #
    def propagate(dsts, message)
        raise NotImplementedError
    end

    # 他ノードより伝送されたメッセージを受け取る
    #
    #@param [String] message_type メッセージの種類
    #@param [String] message 送信データ（JSON）
    #@return [void]
    #
    def receive_propagate(message)
        Supervisor.receive_propagate(message)
    end

    # パスがネットワークレイヤの要求を満たせないことを、Transratorへ通知する。
    #
    #@param [Array<String>] path_ids 要求を満たせないパスIDのリスト
    #@return [void]
    #
    def notify_violation(path_ids)
        Supervisor.notify_violation(path_ids)
    end
end
