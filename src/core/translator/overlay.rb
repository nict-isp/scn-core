# -*- coding: utf-8 -*-
require_relative '../utils'
require_relative './channel'
require_relative './service/inner_service_factory'

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

    #@return [Integer] メッセージの待受けポート
    attr_reader :liten_port

    #@return [Hash] 状態監視要求
    attr_reader :trigger

    #@return [Array<InnerService>] オーバーレイの生成したインナーサービス
    attr_reader :services

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
        @trigger       = {}
        @services      = {}

        # 伝播不要
        @channel_count = 1
        @inner_count   = 1
        # チャネル間でサービスを共有するため検索結果を保存する
        @service_cache = Hash.new{|h, k| h[k] = 
            {"query" => {}, "services" => []}
        }
    end

    #@see Object#marshal_dump
    def marshal_dump()
        # シリアライザブルな状態を保つため、伝播に必要な情報のみをダンプ
        return [@id, @name, @channels, @middleware_id, @supervisor, @liten_port,
                @trigger, @services]
    end

    #@see Object#marshal_load
    def marshal_load(array)
        @id, @name, @channels, @middleware_id, @supervisor, @liten_port,
        @trigger, @services = array
    end

    # チャネルオブジェクトを、チャネルリストへ追加する。
    #
    #@param [ServiceLink] channel チャネルオブジェクト
    #@return [void]
    #
    def create_channel(channel_req)
        log_trace(channel_req)
        resolve_services(channel_req["scratch"])
        resolve_services(channel_req["channel"])

        channel_id = generate_channel_id()
        channel = Channel.new(channel_id, channel_req)
        channel.create(@service_cache)
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
        channel = get_channel(channel_id)
        if channel_req.nil?
            channel_req = channel.channel_req
        end
        resolve_services(channel_req["scratch"])
        resolve_services(channel_req["channel"])

        channel.update(@service_cache, channel_req)
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
        @service_cache.each do |channel_name, cache|
            #TODO 強制削除ではなく、クエリチェックを行うとパスの再生成コストが下がる
            cache["services"].delete_if{|service| service.id == service_id}
        end

        @channels.each do |channel_id, channel|
            update_channel(channel_id, channel.channel_req)
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

    # オーバーレイの実行ログを送信する。
    #
    #@param [Hash] message オーバーレイ実行ログ
    #@return [void]
    #
    def send_message(message = nil)
        if message.nil?
            message = to_message()
        end
        ApplicationRPCClient.receive_message(@id, JSON.generate(message), @liten_port)
    end

    #@return [String] DSNエディタ向けのメッセージ
    #
    def to_message()
        # for DSN Editor
        blocks = @channels.inject(Hash.new{ |h, k| h[k] = {
                "conditions" => nil,
                "is_valid" => true,
                "links" => [],
            }
        }) { |blocks, (channel_id, channel)|
            block = channel.channel_req["block"]
            blocks[block]["conditions"] = block
            blocks[block]["is_valid"] ||= channel.active
            blocks[block]["links"] << channel.to_message
            blocks
        }
        events = @trigger.inject({}) { |events, (event_name, event_hash)|
            events[event_name] = event_hash["state"]
            events
        }
        # for ETL Workflow Editor
        links = @channels.inject({}) { |links, (channel_id, channel)|
            links[channel_id] = channel.to_message
            links
        }
        return {
            "overlay_id" => @id,
            "events" => events,
            "blocks" => blocks.values,
            "links"  => links
        }
    end

    private

    def resolve_services(service_info)
        name  = service_info["name"]
        multi = service_info["multi"]
        inner = service_info["inner"]
        cache = @service_cache[name]
        if inner.nil?
            # 通常のサービス
            if cache["query"] != service_info["query"] ||
                cache["services"].size < multi

                server = service_info["query"]["server"]
                if (not server.nil?()) && (server[0] == "sox")
                    # SOX用サービス
                    service_info["type"] = "sox"
                    service_id = Supervisor.join_service(name, service_info["query"], nil)
                    node_ip    = Supervisor.resolve_service_node(nil)
                    service    = InnerServiceFactory.get_instance(service_id, name, service_info, node_ip)
                    service.start()
                end

                #TODO 全検索を不足分のみの検索にするとパスの再生成コストが下がる
                services = Supervisor.discovery_service(service_info["query"])
                cache["services"] = services.shift(multi)
                cache["query"]    = service_info["query"]
            end
        else
            # インナーサービス
            if cache["inner"].nil?
                node_ip  = Supervisor.resolve_service_node(inner)
                inner_id = generate_inner_id()
                service  = InnerServiceFactory.get_instance(inner_id, name, inner, node_ip)

                cache["services"]   = [service]
                cache["inner"]      = inner
                @services[inner_id] = service

            elsif cache["inner"] != inner
                # 更新時、サービス種別が変わることは考慮しない。
                # （サービス名に関数名が入っている想定）
                cache["services"][0].update(inner)
                cache["inner"] = inner
            end
        end
    end

    # #{ミドルウェアID}_#{オーバーレイID}_#{インナーサービスID}
    #
    def generate_inner_id()
        @inner_count += 1
        inner_id      = @id + '_' + @inner_count.to_s
        return inner_id
    end

    # #{ミドルウェアID}_#{オーバーレイID}_#{チャネルID}
    #
    def generate_channel_id()
        @channel_count += 1
        channel_id      = @id + '_' + @channel_count.to_s
        return channel_id
    end
end

