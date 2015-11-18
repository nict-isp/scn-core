# -*- coding: utf-8 -*-
require_relative '../compile/dsn_define'

#= チャネル要求クラス
# DSNからのチャネル生成・変更時の情報を保持する。
#
#@author NICT
#
class ChannelSettings
    include DSN

    #@return [String]   overlay ID
    attr_reader :overlay
    #@return [String]   channel ID
    attr_accessor :id
    #@return [ServiceInfo] source service
    attr_reader   :src
    #@return [ServiceInfo] destination service
    attr_reader   :dst
    #@return [Hash] application request
    attr_accessor :app_req

    #@param [Hash] link_hash DSN記述チャネル定義
    #@param [Hash] service_hash DSN記述サービス定義
    #
    def initialize(overlay, link_hash, service_hash, block)
        @overlay      = overlay
        @id           = nil
        @block        = block
        @src          = ServiceInfo.new(link_hash[KEY_TRANS_SRC], service_hash)
        @dst          = ServiceInfo.new(link_hash[KEY_TRANS_DST], service_hash)
        @app_req      = link_hash[KEY_APP_REQUEST]
        @log_id       = @app_req["id"]
        @scratch_name = @app_req["scratch"]["name"]
        @channel_name = @app_req["channel"]["name"]
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
        @src.name == @dst.name && @src.query == @dst.query
    end

    # チャネルを活性化する
    #
    #@retun [void]
    #
    def activate()
        if @id.nil?
            @id = Supervisor.create_channel(@overlay, to_request())
        else
            Supervisor.activate_channel(@id)
        end
    end

    # チャネルを非活性化する
    #
    #@retun [void]
    #
    def inactivate()
        if @id.nil?
            # do nothing.
        else
            Supervisor.inactivate_channel(@id)
        end
    end

    # チャネルを削除する
    #
    #@retun [void]
    #
    def delete()
        if @id.nil?
            # do nothing.
        else
            Supervisor.delete_channel(@id)
        end
    end

    # チャネルを更新する
    #
    def update()
        if @id.nil?
            # do nothing.
        else
            Supervisor.update_channel(@id, to_request())
        end
    end

    private

    def to_request()
        return {
            "id" => @log_id,
            "block" => @block,
            "scratch" => {
            "name"  => @scratch_name,
            "query" => @src.query,
            "multi" => @src.multi,
            },
            "channel" => {
            "name"  => @channel_name,
            "query" => @dst.query,
            "multi" => @dst.multi,
            },
            "app_req" => @app_req,
        }
    end
end

#= サービス情報クラス。
# サービス情報を保持する。
#
#@author NICT
#
class ServiceInfo
    #@return [String] scratch or channel name
    attr_accessor   :name
    #@return [Hash] service query
    attr_accessor   :query
    #@return [Integer] multi number
    attr_accessor   :multi

    #@param [String] name scratch or channel name
    #@param [Hash] hash DSN記述サービス定義
    #
    def initialize(name, hash)
        @name  = name
        @query = ServiceHash.query(name, hash)
        @multi = ServiceHash.multi(name, hash)
    end

    #@see Object#==
    def ==(o)
        return @name == o.name && @query == o.query && @multi == o.multi
    end
end

#= チャネル情報クラス。
#
#@author NICT
#
class ServiceHash
    include DSN

    #@param [String] name scratch or channel name
    #@param [Hash] hash DSN記述サービス定義
    #@return [Hash] service query
    #
    def self.query(name, hash)

        query = hash[name].nil?() ? nil : hash[name].select{ |k, v| k != KEY_MULTI }
        return query
    end

    #@param [String] name scratch or channel name
    #@param [Hash] hash DSN記述サービス定義
    #@return [Integer] サービス並列数
    #
    def self.multi(name, hash)
        return hash[name][KEY_MULTI][0].to_i
    end
end

