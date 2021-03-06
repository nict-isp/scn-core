# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative '../utils'
require_relative '../utility/collector'

#= パスクラス
# 対応するフローの生成削除や、データの送受信を依頼する。
# ノード間で同期を行うため、定義情報等を主に扱う。
# 実際に中間処理を行うインスタンスなどは、EventManager・ProcessingManagerで生成される。
#
#@author NICT
#
class Path

    #@return {String] パスID
    attr_reader :id

    #@return {Service] 送信元サービス
    attr_reader :src_service

    #@return {Service] 送信先サービス
    attr_reader :dst_service

    #@return [Array<String>] IPと中間処理要求の配列
    attr_reader :processings

    #@param {String] id パスID
    #@param {Service] src_service 送信元サービス
    #@param {Service] dst_service 送信先サービス
    #@param [Array<String>] processings IPと中間処理要求の配列
    #
    def initialize(id, src_service, dst_service, processings = [])
        log_trace(id, src_service, dst_service, processings)
        @id          = id
        @src_service = src_service
        @dst_service = dst_service
        @processings = processings

        EventCollector.set_path(self)
    end

    # フローを生成する。
    #
    #@return [void]
    #
    def create()
        # 1つのパスは複数のフローからなる
        # データ送信時、パスIDを指定することで次の宛先がわかる
        @flows = create_flows(@processings)
        @flows.each do |src, dst|
            NCPS.create_flow(@id, src, dst)
        end

        if @flows.size == 0
            # フローがないとSCN-Visualizer上に表示されないため
            # ダミーのサービス連携生成メッセージを飛ばす。
            EventCollector.create_flow(@id, get_dummy_flow_id())
        end
    end

    # 中間処理に合わせて、フローを変更する。
    #
    #@param [Array<String>] processings IPと中間処理要求の配列
    #@return [void]
    #
    def update(processings)
        new_flows = create_flows(processings)

        (@flows - new_flows).each do |src, dst|
            NCPS.delete_flow(@id, src)    # 送信元を指定するので先に削除
        end
        (new_flows - @flows).each do |src, dst|
            NCPS.create_flow(@id, src, dst)
        end

        # 必要に応じてダミーのサービス連携を生成・削除 
        if @flows.size == 0 && new_flows.size > 1
            EventCollector.delete_flow(@id, get_dummy_flow_id())

        elsif @flows.size > 1 && new_flows.size == 0
            EventCollector.create_flow(@id, get_dummy_flow_id())
        end

        @flows       = new_flows
        @processings = processings
    end

    # フローを削除する。
    #
    #@return [void]
    #
    def delete()
        NCPS.delete_flow(@id)

        if @flows.size == 0
            EventCollector.delete_flow(@id, get_dummy_flow_id())
        end
    end

    # データを送信する。
    #
    #@return [void]
    #
    def send(data, data_size)
        if @flows.size > 0
            NCPS.send_data(@id, data, data_size)
        else
            # フローのない場合は自ノード宛
            NCPS.receive_data(@id, data, data_size)
        end
    end

    #@param {Service] src_service 送信元サービス
    #@param {Service] dst_service 送信先サービス
    #@return [True] 送信元、送信先が同じ
    #@return [False] 送信元、送信先が異なる
    #
    def same_path?(src_service, dst_service)
        log_trace(src_service, dst_service)
        return @src_service.id == src_service.id && @dst_service.id == dst_service.id
    end

    #@param [String] service_id サービスID
    #@return [True] サービスが含まれる
    #@return [False] サービスは含まれない
    #
    def include_service?(service_id)
        return @src_service.id == service_id || @dst_service.id == service_id
    end

    #@return [True] 送信先が自ノード
    #@return [Flase] 送信先が他ノード
    #
    def current_dst?
        return current_node?(dst_service.ip)
    end

    private

    # 中継ノードを経由する際の送信元ノード、送信先ノードのペアを返す
    #
    def create_flows(processings)
        flows = []
        src = @src_service.ip
        dst = @dst_service.ip
        processings.each do |ip, processing|
            next if ip == src
            flows << [src, ip]
            src = ip
        end
        flows << [src, dst] if src != dst
        return flows
    end

    def get_dummy_flow_id()
        return "s#{@id}_bi_d#{@id}"
    end
end
