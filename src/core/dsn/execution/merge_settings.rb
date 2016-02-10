# -*- coding: utf-8 -*-
require_relative '../compile/dsn_define'
require_relative './channel_settings'

#= マージ要求クラス
# DSNからのマージ要求を、チャネルに変換し、生成・変更する。
#
#@author NICT
#
class MergeSettings
    include DSN

    #@return [Hash] merge channel request
    attr_reader   :channel
    #@return [String] source channel
    attr_reader   :dst
    #@return [Array<String>] destination channels
    attr_reader   :srcs
    #@return [Boolean] merge is active
    attr_reader   :active
    #@return [String] merge block name
    attr_reader   :block
    #@return [String] merge application request
    attr_reader   :app_req

    #@param [Hash] merge_hash DSN記述マージ定義
    #@param [Hash] channels_hash DSN記述チャネル定義
    #
    def initialize(overlay, merge_hash, service_hash)
        @overlay  = overlay
        @paths    = {}
        @active   = true

        update(merge_hash, service_hash)
    end

    # マージ要求を更新する
    #
    #@param [Hash] merge_hash DSN記述マージ定義
    #@param [Hash] channels_hash DSN記述チャネル定義
    #@return [void]
    #
    def update(merge_hash, service_hash)
        @dst     = merge_hash[KEY_MERGE_DST]
        @srcs    = merge_hash[KEY_MERGE_SRC]
        @block   = "#{@dst}##{merge_hash[KEY_TYPE]}"
        @app_req = merge_hash[KEY_APP_REQUEST]
        @channel = {
            "inner" => merge_hash,
            "name"  => @block,
            "multi" => 1,
        }
        @srcs.each do |src|
            service = service_hash[src]
            scratch = {
                "name"    => src,
                "channel" => "#{@overlay}##{src}",
                "query"   => service.query,
                "multi"   => service.multi,
            }
            create_settings(src, scratch, @channel)
        end
    end

    # チャネルを活性化する
    #
    #@return [void]
    #
    def activate()
        @active = true
        @paths.each do |src, path|
            if @srcs.include?(src)
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
        @active = false
        @paths.values.each do |path|
            path.inactivate()
        end
    end

    private 

    # チャネル要求を生成する。生成済みの場合はチャネル要求を更新する
    #
    def create_settings(src, scratch, channel)
        app_req = {
            "channel" => {
                "name"   => channel["name"],
                "select" => [],
                "meta"   => {},
            },
            "scratch" => {
                "name"    => scratch["name"],
                "select"  => [],
                "meta"    => {},
            },
            "processing" => [],
            "qos"        => {},
        }
        path = @paths[src]
        if path.nil?
            @paths[src] = ChannelSettings.new(@overlay, scratch, channel, app_req, @block)
        else
            path.update(scratch, channel, app_req)
        end
    end
end

