# -*- coding: utf-8 -*-
require 'json'

require_relative '../../utils'
require_relative '../../utility/collector'
require_relative '../compile/dsn_define'
require_relative './dsn_block'
require_relative './complex_channel_settings'
require_relative './merge_settings'

#= オーバーレイ状態管理クラス
# オーバーレイ状態を管理する。
#
class DSNOperator
    include DSN

    #@return [String]   オーバーレイID
    attr_reader   :id
    #@return [String]   オーバーレイ名
    attr_reader   :overlay_name
    #@return [Array]    チャネル設定定義ブロック（bloom do＋event do）
    attr_reader   :blocks

    #@param [String] id オーバーレイID
    #@param [Hash] dsn_hash DSN記述（中間コード）
    #
    def initialize(id, dsn_hash)
        log_trace(id, dsn_hash)
        @id           = id
        @dsn_hash     = dsn_hash
        @overlay_name = dsn_hash[KEY_OVERLAY]
        @event_state  = {}
        @merges       = {}
        parse_blocks(dsn_hash)
    end

    #@return [String] 応答メッセージ
    #@raise [ApplicationError] SCNミドルウェアのAPI呼出でエラーが発生した場合
    #
    def create_overlay()
        update_trigger()
        return update_overlay({})
    end

    #@return [String] 応答メッセージ
    #@raise [ApplicationError] SCNミドルウェアのAPI呼出でエラーが発生した場合
    #
    def update_overlay(event_state)
        log_time()
        log_debug{"input  #{event_state}"}

        log_debug{"before #{@event_state}"}
        @event_state.merge!(event_state)
        log_debug{"after  #{@event_state}"}

        log_time()
        update()
    end

    #@param [Hash] dsn_hash DSN記述（中間コード）
    #@return [void]
    #@raise [ApplicationError] SCNミドルウェアのAPI呼出でエラーが発生した場合
    #
    def modify_overlay(dsn_hash)
        log_time()

        @dsn_hash      = dsn_hash
        services_hash  = dsn_hash[KEY_SERVICES]
        @channels_hash = create_channels_hash(dsn_hash, services_hash)
        sl_empty_hash  = { KEY_SERVICE_LINK => []}

        log_debug(){"@blocks = #{@blocks}"}

        # 削除されているブロックを、@blocks から削除する。
        deleted_blocks = []
        @blocks.each do |block|
            if not block.event_cond.nil?
                if not dsn_hash[KEY_EVENTS].any? { |event_hash| block.event_cond == event_hash[KEY_CONDITIONS] }
                    deleted_blocks << block
                    # 空のhashを与えることでブロック内のチャネルを削除する。
                    block.modify({KEY_SERVICE_LINK => []}, {KEY_SERVICES => nil})
                end
            end
        end
        @blocks = @blocks - deleted_blocks

        # 変更されているいるブロックを、更新する。
        @blocks.each do |block|
            if block.event_cond.nil?
                block.modify(dsn_hash, @channels_hash)
            else
                event_hash = dsn_hash[KEY_EVENTS].find { |event_hash| block.event_cond == event_hash[KEY_CONDITIONS] }
                block.modify(event_hash, @channels_hash)
            end
        end

        # 追加されているブロックを、@blocks へ追加する。
        dsn_hash[KEY_EVENTS].each do |event_hash|
            if not @blocks.any? { |sls_block| sls_block.event_cond == event_hash[KEY_CONDITIONS] }
                @blocks << DSNEventBlock.new(@id, event_hash, @channels_hash)
            end
        end

        log_debug(){"@blocks = #{@blocks}"}

        update()
    end

    private

    # DSNからのサービス定義を、スクラッチ・チャネル名をキーにした形に変換
    #
    def create_channels_hash(dsn_hash, services_hash)
        channels_hash = {}
        block_hash_array = [dsn_hash]
        dsn_hash[KEY_EVENTS].each do |event_hash|
            block_hash_array << event_hash
        end
        block_hash_array.each do |block_hash|
            block_hash[KEY_SERVICE_LINK].each do |link_hash|
                app_req = link_hash[KEY_APP_REQUEST]
                channels_hash[app_req["scratch"]["name"]] = ServiceInfo.new(link_hash[KEY_TRANS_SRC], services_hash)
                channels_hash[app_req["channel"]["name"]] = ServiceInfo.new(link_hash[KEY_TRANS_DST], services_hash)
            end
        end
        return channels_hash
    end

    #@raise [ArgumentError] DSN記述不整合
    #@note ここで検出するエラーは、中間コードの構造上の不整合
    #      定義内容の不整合は（サービスが存在しない、イベントブロックに
    #      対応するトリガがない等）はAPI実行時にエラー検出する。
    #
    def parse_blocks(dsn_hash)
        # state do ブロック
        services_hash = dsn_hash[KEY_SERVICES]
        # bloom do ブロック
        @channels_hash = create_channels_hash(dsn_hash, services_hash)
        @blocks = []
        @blocks << DSNConstantBlock.new(@id, dsn_hash, @channels_hash)
        # events do ブロック
        dsn_hash[KEY_EVENTS].each do |event_hash|
            @blocks << DSNEventBlock.new(@id, event_hash, @channels_hash)
        end
    end

    def update
        log_time()

        # イベント状態に基づいてブロックの状態を更新
        @blocks.each do |block|
            block.update_state(@event_state)
        end

        # 有効なマージの設定を更新
        update_merges()
        active_merges = @merges.select{|k, v| v.active}
        @blocks.each do |block|
            # ブロック内のパスの状態を更新
            block.update(active_merges)
        end

        # 有効なトリガの設定を更新
        update_trigger()

        log_time()
    end

    # マージ要求を生成・変更する。
    # マージ要求はDSN全体に影響するので、ここ（ブロックの外）で生成する。
    #
    def update_merges()
        merges = {}
        @blocks.each do |block|
            merges = block.merge_merges(merges)           
        end
        log_debug{"merges = #{merges}"}

        # dstごとにマージ要求を生成・変更
        merges.each do |channel, merge|
            merge_setting =  @merges[channel]
            begin
                if merge_setting.nil?
                    merge_setting = MergeSettings.new(@id, merge, @channels_hash)
                    @merges[channel] = merge_setting
                else
                    merge_setting.update(merge, @channels_hash)
                end
            rescue
                log_error("", $!)
            end
        end
       
        active_channels = merges.keys()
        @merges.each do |channel, merge|
            begin
                if active_channels.include?(channel)
                    merge.activate()
                else
                    merge.inactivate()
                end
            rescue
                log_error("", $!)
            end
        end 

        log_debug{"@merges = #{@merges}"}
    end

    def update_trigger()
        # 全イベントに対する空のトリガを作成してセット
        trigger = {}
        @blocks.each do |block|
            trigger = block.merge_trigger(trigger)
        end

        trigger.each do |event_name, hash|
            if @event_state[event_name].nil?
                @event_state[event_name] = false
                hash["state"] = false
            else
                hash["state"] = @event_state[event_name]
            end
        end

        Supervisor.set_trigger(@id, trigger)
    end
end
