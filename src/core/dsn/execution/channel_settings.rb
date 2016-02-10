# -*- coding: utf-8 -*-
require_relative '../compile/dsn_define'

#= チャネル要求クラス
# チャネル生成・変更時の情報を保持する。
#
#@author NICT
#
class ChannelSettings
    include DSN

    #@return [String]   overlay ID
    attr_reader :overlay
    #@return [String]   channel ID
    attr_accessor :id
    #@return [Hash] application request
    attr_accessor :app_req

    #@param [String] overlay オーバーレイID
    #@param [Hash] scratch 送信側チャネル要求
    #@param [Hash] channel 受信側チャネル要求
    #@param [Hash] app_req 中間処理要求
    #@param [String] block DSNブロック名
    #
    def initialize(overlay, scratch, channel, app_req, block)
        @overlay      = overlay
        @id           = nil
        @scratch      = scratch
        @channel      = channel
        @app_req      = app_req
        @log_id       = app_req["id"]
        @block        = block
        @needs_update = false
    end

    # チャネルを活性化する
    #
    #@retun [void]
    #
    def activate()
        if @id.nil?
            @id = Supervisor.create_channel(@overlay, to_request())
        else
            if @needs_update
                Supervisor.update_channel(@id, to_request())
            end
            Supervisor.activate_channel(@id)
        end
        @needs_update = false
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
    def update(scratch, channel, app_req)
        if (@scratch != scratch) || (@channel != channel) || (@app_req != app_req)
            @scratch      = scratch
            @channel      = channel
            @app_req      = app_req
            @needs_update = true
        end
    end

    private

    def to_request()
        return {
            "id" => @log_id,
            "block" => @block,
            "scratch" => @scratch,
            "channel" => @channel,
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

