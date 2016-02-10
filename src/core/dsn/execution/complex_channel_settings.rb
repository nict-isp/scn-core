# -*- coding: utf-8 -*-
require_relative '../compile/dsn_define'
require_relative './channel_settings'

#= 複合チャネル要求クラス
# DSNからのチャネル要求を、複数のチャネルに分解し、生成・変更する。
#
#@author NICT
#
class ComplexChannelSettings
    include DSN

    #@return [ServiceInfo] source service
    attr_reader   :src
    #@return [ServiceInfo] destination service
    attr_reader   :dst
    #@return [Hash] application request
    attr_accessor :app_req

    #@param [Hash] link_hash DSN記述転送定義
    #@param [Hash] channels_hash DSN記述チャネル定義
    #@param [String] block DSNブロック名
    #
    def initialize(overlay, link_hash, channels_hash, block)
        @overlay      = overlay
        @block        = block
        @paths        = {}
        @active_paths = []

        update(link_hash, channels_hash)
    end

    #@see Object#==
    def ==(o)
        @src == o.src && @dst == o.dst && @app_req == o.app_req
    end

    #@param [ChannelSettings] o ChannelSettingsオブジェクト
    #@return [True] 送受信先の設定が同じ
    #@return [False] 送受信先の設定が異なる
    #
    def same_channel?(o)
        @src == o.src && @dst == o.dst
    end

    # チャネル要求を更新する
    #
    #@param [Hash] link_hash DSN記述転送定義
    #@param [Hash] channels_hash DSN記述チャネル定義
    #@return [void]
    #
    def update(link_hash, channels_hash)
        @app_req     = link_hash[KEY_APP_REQUEST]
        @log_id      = @app_req["id"]
        
        scratch_name = @app_req["scratch"]["name"]
        channel_name = @app_req["channel"]["name"]
        @src         = channels_hash[scratch_name]
        @dst         = channels_hash[channel_name]
        @scratch = {
            "name"  => scratch_name,
            "query" => @src.query,
            "multi" => @src.multi,
        }
        @channel = {
            "name"  => channel_name,
            "query" => @dst.query,
            "multi" => @dst.multi,
        }
    end
    
    # チャネル要求を実際のチャネルに分解、生成する。
    #
    #@param [Hash<String, MergeSettings>] merge_settings マージ要求
    #@return [void]
    #
    def update_path(merge_settings)
        active_paths = []

        scratch     = @scratch.dup
        channel     = @channel.dup
        select      = @app_req["scratch"]["select"].dup
        processings = @app_req["processing"].dup

        # aggregte関数のある場合、関数前後でパスを分割
        aggregate = processings.index{|processing| processing.has_key?("aggregate")}
        if aggregate
            # パス前半の中間処理
            if aggregate > 0
                aggregate_processing = processings.slice(0..aggregate - 1)
            else
                aggregate_processing = []
            end
            # aggregateサービス要求
            aggregate_req = processings[aggregate]["aggregate"]
            aggregate_req["type"] = "aggregate"
            aggregate_channel     = {
                "inner" => aggregate_req,
                "name"  => "#{scratch["name"]}#aggregate",
                "multi" => 1,
            }
            # aggregateサービスまでのパスを生成
            active_paths << create_settings("aggregate", scratch, aggregate_channel, select, aggregate_processing, @block)

            # パスの残りを設定
            select      = []
            processings = processings.slice(aggregate + 1..-1)
            scratch     = aggregate_channel
        end
    
        # merge関数のdstに設定されている場合、mergeを経由する形でパスを生成
        merge_pair = merge_settings.find{|key, merge| merge.dst == @channel["name"] }
        if merge_pair.nil?
            # 通常のパス
            active_paths << create_settings("normal", scratch, channel, select, processings, @block)
        else
            merge = merge_pair[1]
            # mergeへの入力とmergeからの出力用のパスを生成
            active_paths << create_settings("merge_in", scratch, merge.channel, select, processings, @block)
            active_paths << create_settings("merge_out", merge.channel, channel, merge.app_req["select"], merge.app_req["processing"], merge.block)
        end

        @active_paths = active_paths
    end

    # チャネルを活性化する
    #
    #@param [Hash<String, MergeSettings>] merge_settings マージ要求
    #@return [void]
    #
    def activate(merge_settings)
        update_path(merge_settings)

        @paths.values.each do |path|
            if @active_paths.include?(path)
                path.activate()
            else
                path.inactivate()
            end
        end
    end

    # チャネルを非活性化する
    #
    #@retun [void]
    #
    def inactivate()
        @paths.values.each do |path|
            path.inactivate()
        end
    end

    # チャネルを削除する
    #
    #@retun [void]
    #
    def delete()
        @paths.values.each do |path|
            path.delete()
        end
    end

    private 

    # チャネル要求を生成する。生成済みの場合はチャネル要求を更新する
    #
    def create_settings(key, scratch, channel, select, processings, block)
        app_req = deep_copy(@app_req)
        app_req["scratch"]["select"] = select
        app_req["processing"]        = processings

        path = @paths[key]
        if path.nil?
            log_debug{"key = #{key}, processings = #{processings}"}
            path = ChannelSettings.new(@overlay, scratch, channel, app_req, block)
            @paths[key] = path
        else
            path.update(scratch, channel, app_req)
        end
        return path
    end
end

