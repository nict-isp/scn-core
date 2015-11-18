# -*- coding: utf-8 -*-
require_relative '../utils'
require_relative './channel'

#= オーバーレイクラス
# オーバーレイを構成するチャネルの生成管理を行う。
# ノード間で同期を行うため、定義情報等を主に扱う。
# 実際に中間処理を行うインスタンスなどは、EventManager・ProcessingManagerで生成される。
#
#@author NICT
#
class Overlay
    #@return [String] オーバーレイID
    attr_reader :id

    #@return [String] オーバーレイ名
    attr_reader :name

    #@return [String] チャネルの集合
    attr_reader :channels

    #@return [String] このオーバーレイを管理する Supervisor のミドルウェアID
    attr_reader :middleware_id

    #@return [String] このオーバーレイを管理する Supervisor のIPアドレス
    attr_reader :supervisor

    attr_reader :liten_port

    #@return [Hash] 状態監視要求
    attr_reader :trigger

    #@param [String] id オーバーレイID
    #@param [String] name オーバーレイ名
    #@param [String] middleware_id このオーバーレイを管理する Supervisor のミドルウェアID
    #
    def initialize(id, name, middleware_id, ip, liten_port = nil)
        @id            = id
        @name          = name
        @channels      = {}
        @middleware_id = middleware_id
        @supervisor    = ip
        @liten_port    = liten_port
        @channel_count = 1
        @trigger       = {}
    end

    # チャネルオブジェクトを、チャネルリストへ追加する。
    #
    #@param [ServiceLink] channel チャネルオブジェクト
    #@return [void]
    #
    def create_channel(channel_req)
        log_trace(channel_req)
        channel_id = generate_channel_id()
        channel = Channel.new(channel_id, channel_req)
        channel.create()
        @channels[channel_id] = channel

        return channel_id
    end

    #@param [String] channel_id チャネルのID
    #@return [Channel] チャネル
    #@raise [InvalidIDError] 存在しないチャネルIDが指定された
    #
    def get_channel(channel_id)
        channel = @channels[channel_id]
        if channel.nil?
            raise InvalidIDError, channel_id
        end
        return channel
    end

    #@param [String] channel_id 更新するチャネルのID
    #@param [Hash] channel_req 更新後のチャネル要求
    #@raise [InvalidIDError] 存在しないチャネルIDが指定された
    #
    def update_channel(channel_id, channel_req)
        get_channel(channel_id).update(channel_req)
    end

    #@param [String] channel_id 活性化するチャネルのID
    #@raise [InvalidIDError] 存在しないチャネルIDが指定された
    #
    def activate_channel(channel_id)
        get_channel(channel_id).activate()
    end

    #@param [String] channel_id 非活性化するチャネルのID
    #@raise [InvalidIDError] 存在しないチャネルIDが指定された
    #
    def inactivate_channel(channel_id)
        get_channel(channel_id).inactivate()
    end

    #@param [String] channel_id 削除するチャネルのID
    #@raise [InvalidIDError] 存在しないチャネルIDが指定された
    #
    def delete_channel(channel_id)
        channel = @channels.delete(channel_id)
        if channel.nil?
            log_warn("invalid channel id = #{channel_id}")
        else
            channel.delete()
        end
    end

    # オーバーレイを削除する。構成するチャネルも削除する。
    #
    def delete()
        @channels.each_value do |channel|
            channel.delete()
        end
    end

    #@param [String] channel_id チャネルID
    #@return [True] オーバーレイがチャネルを含むとき
    #@return [Falase] オーバーレイがチャネルを含まないとき
    #
    def include_channel?(channel_id)
        return @channels.include?(channel_id)
    end

    #@param [String] service_id サービスID
    #@return [True] オーバーレイがサービスを含むとき
    #@return [Falase] オーバーレイがサービスを含まないとき
    #
    def include_service?(service_id)
        return @channels.find{ |channel_id, channel| channel.include_service?(service_id) }
    end

    # チャネルにサービスの更新を通知する。
    #
    #@param [String] service_id サービスID
    #@param [Service] service 更新されたサービス（削除時nil）
    #@return [void]
    #
    def update_service(service_id, service)
        @channels.each do |channel_id, channel|
            channel.update_service(service_id, service)
        end
    end

    #@param [Hash] trigger トリガ情報を設定する（反映は伝搬後）
    #
    def set_trigger(trigger)
        @trigger = trigger
    end

    #@param [Hash] events イベント情報を設定する（反映は伝搬後）
    #
    def set_events(events)
        @events = events
    end

    #@return [Array<String>] オーバーレイ（チャネル）を構成するノードの一覧
    #
    def get_nodes()
        nodes = []
        @channels.each do |id, channel|
            nodes |= channel.get_nodes()
        end
        return nodes.uniq
    end
    
    #@return [Array<String>] このノードでデータを受信するチャネル名のリスト
    #
    def get_current_channels()
        channels = []
        @channels.each do |id, channel|
            channels << channel.name if channel.current_channels?
        end
        return channels
    end

    #@return [String] DSNエディタ向けのメッセージ
    #
    def to_message()
        blocks = @channels.inject(Hash.new{ |h, k| h[k] = {
                "conditions" => nil,
                "is_valid" => true,
                "links" => [],
            }
        }) { |blocks, (channel_id, channel)|
            block = channel.channel_req["block"]
            blocks[block]["conditions"] = block
            blocks[block]["is_valid"] &&= channel.active
            blocks[block]["links"] << channel.to_message
            blocks
        }

        events = @trigger.inject({}) { |events, (event_name, event_hash)|
            events[event_name] = event_hash["state"]
            events
        }

        return {
            "overlay_id" => @id,
            "events" => events,
            "blocks" => blocks.values
        }
    end

    private

    # #{ミドルウェアID}_#{オーバーレイID}_#{チャネルID}
    #
    def generate_channel_id()
        @channel_count += 1
        channel_id      = @id + '_' + @channel_count.to_s
        return channel_id
    end
end

