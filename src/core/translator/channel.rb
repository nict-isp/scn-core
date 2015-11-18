# -*- coding: utf-8 -*-
require_relative './service'
require_relative './path_creator'
require_relative '../utility/collector'

#= チャネルクラス
# チャネルを構成するパスの管理を行う。
# チャネルはリクエストに応じて複数のパスを生成する。
# ノード間で同期を行うため、定義情報等を主に扱う。
# 実際に中間処理を行うインスタンスなどは、EventManager・ProcessingManagerで生成される。
#
#@author NICT
#
class Channel
    #@return [String] チャンネルID
    attr_reader :id
    #@return [String] チャンネル名
    attr_reader :name
    #@return [Hash] アプリケーション要求
    attr_reader :channel_req
    #@return [True] 活性状態
    #@return [False] 非活性状態
    attr_reader :active
    #@return [Array<Paht>] チャネルに紐づくパスの配列
    attr_reader :paths

    #@param [String] id チャネルID
    #@param [ChannelRequest] channel_req アプリケーション要求
    #
    def initialize(id, channel_req)
        log_trace(id, channel_req)
        @id           = id
        @name         = channel_req["channel"]["name"]
        @channel_req  = channel_req
        @active       = true
        @path_creater = SimplePathCreator.new(id)
        @paths        = []
    end

    # フローを作成し、データの送受信を可能な状態にする
    #
    #@return [void]
    #
    def create()
        log_time()
        @paths = @path_creater.create(@channel_req)
        log_time()

        set_retry()
    end

    # アプリケーション要求を更新し、フローを再生成する。
    #
    #@param [Hash] app_request アプリケーション要求(フィルタ条件やQoSなど)
    #@return [void]
    #@raise [ArgumentError] 未サポートのアプリケーション要求が指定された。
    #
    def update(channel_req = nil)
        log_debug() {"channel request = \"#{channel_req}\""}
        log_time()
        @channel_req = channel_req unless channel_req.nil?
        @paths = @path_creater.update(@paths, @channel_req)
        log_time()

        set_retry()
    end

    # フローを削除する。
    #
    #@return [void]
    #
    def delete()
        log_time()
        @paths.each {|path| path.delete()}
        log_time()
    end

    # パスを活性化し、データの送受信を許可する
    #
    #@return [void]
    #
    def activate()
        unless @active
            @active = true
            @paths.each {|path| EventCollector.activate_path(path)}
        end
    end

    # パスを非活性化し、データの送受信を止める
    #
    #@return [void]
    #
    def inactivate()
        if @active
            @active = false
            @paths.each {|path| EventCollector.inactivate_path(path)}
        end
    end

    #@param [String] service_id サービスID
    #@return [True] チャネルがサービスを含むとき
    #@return [Falase] チャネルがサービスを含まないとき
    #
    def include_service?(service_id)
        return @paths.find{ |path| path.include_service?(service_id) }
    end

    # サービス情報の更新に伴うパスの再生成を行う
    #
    #@param [String] service_id サービスID
    #@param [Service] service 更新されたサービス（削除時nil）
    #@return [True] アップデートした
    #@return [False] アップデートしなかった
    #
    def update_service(service_id, service)
        #TODO サービスが条件を満たさなくなった場合のみupdateするのがよい
        update()
        return true
    end

    #@return [Array<String>] チャネル（パス）を構成するノードの一覧
    #
    def get_nodes()
        nodes = []
        @paths.each do |path|
            nodes << path.src_service.ip
            nodes << path.dst_service.ip
        end
        return nodes.uniq
    end

    #@return [True] このノードでデータを受信するチャネル
    #@return [False] このノード以外でデータを受信するチャネル
    #
    def current_channels?()
        return @paths.any? {|path| path.current_dst?}  
    end

    #@return [String] DSNエディタ向けのメッセージ
    #
    def to_message
        return {
            "link_id"  => @channel_req["id"],
            "scratch"  => @channel_req["scratch"]["name"],
            "channel"  => @channel_req["channel"]["name"],
            "expected" => expected(),
            "actual"   => @active ? @paths.size : 0
        }
    end

    private

    def expected
        return [1, @channel_req["scratch"]["multi"], @channel_req["channel"]["multi"]].max
    end

    def set_retry()
        log_debug {"id: #{@id}, actual: #{@paths.size}, expect: #{expected()}"}
        if @paths.size < expected()
            #TODO リトライ方式の検討
            Thread.new do
                begin
                    sleep 3
                    Supervisor.update_channel(@id)
                rescue
                    log_warn("id: #{@id}, set_retry: #{$!}")
                end
            end
        end
    end
end

