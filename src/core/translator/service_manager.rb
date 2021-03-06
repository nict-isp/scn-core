# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require 'singleton'

require_relative '../utils'
require_relative '../utility/message'
require_relative '../utility/collector'
require_relative '../utility/sync'
require_relative './service/service'
require_relative './service_discovery'
require_relative './../dsn/processing/processing'
require_relative './../dsn/processing/aggregate'

#= サービス管理クラス
# サービスに関して以下の機能を提供する。
#    - 追加
#    - 更新
#    - 削除
#    - 参照
#    - 検索
#
#@author NICT
#
class ServiceManager
    include Message

    # サービス管理クラスを生成する。
    #
    #@param [String] service_id サービスID
    #@param [String] server_ip サービス管理サーバのIP
    #@return [Service] サービスオブジェクト
    #
    def self.create(middleware_id, server_ip)
        if current_node?(server_ip)
            service_manager = ServiceManagerServer.new(middleware_id, server_ip)
        else
            service_manager = ServiceManagerClient.new(middleware_id, server_ip)
        end
        return service_manager
    end

    #@param [String] service_id サービスID
    #@param [String] server_ip サービス管理サーバのIP
    #
    def initialize(middleware_id, server_ip)
        @middleware_id = middleware_id
        @server_ip     = server_ip
        @service_list  = SyncHash.new()
        @service_count = 0
    end

    #@param [String] service_id サービスID
    #@return [Service] サービスオブジェクト
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #
    def get_service(service_id)
        log_trace(service_id)
        service = @service_list[service_id]
        if service.nil?
            raise InvalidIDError, service_id
        end
        return service
    end

    # サービス検索を行なう。
    #
    #@param [String] query 検索条件
    #@param [Integer] reqire 要求数
    #
    def discovery_service(query, reqire=nil)
        raise NotImplementedError
    end

    # サービスをSCN空間に参加させる。
    #
    #@param [String] service_name サービス名
    #@param [Hash] service_info サービスの情報
    #@param [Hash] resource 資源情報情報
    #@param [Integer] port データ受信用ポート番号
    #@return [String] サービスID
    #@raise [ArgumentError] サービス情報の形式が誤っている。
    #
    def join_service(service_name, service_info, port)
        service = create_service(service_name, service_info, port)
        add_service(service)

        EventCollector.join_service(service)
        return service.id
    end

    #@param [String] service_id 離脱するサービスのID
    #
    def leave_service(service_id)
        service = delete_service(service_id)

        propagate(service_id, nil)
        EventCollector.leave_service(service)
    end

    # サービス情報を更新する。
    #
    #@param [String] service_id サービスID
    #@param [Hash] service_info サービスの情報
    #@return [Service] サービスオブジェクト
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #@raise [ArgumentError] サービス情報の形式が誤っている。
    #
    def update_service(service_id, service_info)
        service = update_service_inner(service_id, service_info)

        propagate(service.id, service)
        EventCollector.update_service(service)
    end

    # 統計情報を更新する。
    #
    #@param [String] ip ノードのIPアドレス
    #@param [Hash] stats ノードの統計情報
    #@return [void]
    #
    def update_stats(ip, stats)
        raise NotImplementedError
    end

    # インナーサービスの生成先ノードを解決する
    #
    #@param [Hash] 生成するサービス情報
    #@return [String] 生成先ノードのIPアドレス
    #
    def resolve_service_node
        raise NotImplementedError
    end

    # サービスを解決する（立ち上げる）
    #
    #@param [String] type サービスのタイプ
    #@param [Hash] params サービスのパラメータ
    #@return [String] サービスID
    #
    def resolve_service_node(type, params)
        raise NotImplementedError
    end

    private

    #@param [String] service_id サービスID
    #@param [Hash] service_info サービスの情報
    #@return [Service] サービスオブジェクト
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #
    def update_service_inner(service_id, service_info)
        log_trace(service_id, service_info)

        service = get_service(service_id)
        service.info = deep_copy(service_info)

        return service
    end

    #@param [Service] service サービスオブジェクト
    #@return [void]
    #
    def add_service(service)
        # service_idが重複していた場合は、最新状態にするため上書きする。
        @service_list[service.id] = service

        log_debug() {"service list = \"#{@service_list}\""}
    end

    #@param [String] service_id サービスID
    #@return [Service] サービスオブジェクト
    #@raise [InvalidIDError] 指定されたIDが無効の場合
    #
    def delete_service(service_id)
        log_trace(service_id)

        service = @service_list.delete(service_id)
        if service.nil?
            log_waran("service ID = \"#{service_id}\" isn't exist.")
        end

        return service
    end

    # #{ミドルウェアID}_#{サービスID}
    #
    def generate_service_id()
        @service_count += 1
        service_id      = @middleware_id + '_' + @service_count.to_s
        return service_id
    end

    def create_service(service_name, service_info, port)
        log_trace(service_name, service_info, port)

        service_id           = generate_service_id()
        service_info["name"] = service_name
        service              = Service.new(service_id, service_name, service_info, $ip, port)
        return service
    end

    # サービスを利用しているオーバーレイに伝搬する。
    #
    def propagate(service_id, service)
        overlays = Supervisor.get_overlays_by_service_id(service_id)
        dsts = overlays.map{ |overlay| overlay.supervisor }.uniq
        send_propagate(dsts, PROPAGATE_SERVICE_MANAGER, "set_service", [service_id, service])
    end

    def set_service(service_id, service)
        # 自ノードの情報もこのシーケンスで反映させる。
        Supervisor.update_overlays_by_service(service_id, service)
    end

    # インスタンスメソッドをクラスに委譲
    class << self
        extend Forwardable
        def_delegators :instance, *ServiceManager.instance_methods(false)
    end
end

#= サービスクライアントクラス
# サービスに関して以下の機能をサーバーに問い合わせる。
#    - 追加
#    - 更新
#    - 削除
#    - 参照
#    - 検索
#
#@author NICT
#
class ServiceManagerClient < ServiceManager

    def initialize(*args)
        super
    end

    #@see ServiceManager#discovery_service
    def discovery_service(query, reqire=nil)
        log_trace(query)

        log_info("search query  = #{query}, reqire = #{reqire}")
        services = send_request(@server_ip, REQUEST_SERVICE_MANAGER, "discovery_service", [query, reqire])
        log_info("search result = #{services}, size = #{services.size}")

        return services
    end

    #@see ServiceManager#join_service
    def join_service(service_name, service_info, port)
        service_id = super
        service = get_service(service_id)

        send_request(@server_ip, REQUEST_SERVICE_MANAGER, "add_service", [service])
        return service.id
    end

    #@see ServiceManager#leave_service
    def leave_service(service_id)
        send_request(@server_ip, REQUEST_SERVICE_MANAGER, "delete_service", [service_id])
        super
    end

    #@see ServiceManager#update_service
    def update_service(service_id, service_info)
        send_request(@server_ip, REQUEST_SERVICE_MANAGER, "update_service_inner", [service_id, service_info])
        super
    end

    #@see ServiceManager#update_stats
    def update_stats(ip, stats)
        #send_request(@server_ip, REQUEST_SERVICE_MANAGER, "update_stats_inner", [ip, stats])
        send_request(@server_ip, PROPAGATE_SERVICE_MANAGER, "update_stats_inner", [ip, stats])
    end

    #@see ServiceManager#resolve_service_node
    def resolve_service_node(param)
        send_request(@server_ip, REQUEST_SERVICE_MANAGER, "resolve_service_node", [param])
    end   
end

#= サービスサーバクラス
# サービスに関して以下の機能を提供する。
#    - 追加
#    - 更新
#    - 削除
#    - 参照
#    - 検索
#
#@author NICT
#
class ServiceManagerServer < ServiceManager

    def initialize(*args)
        super
        @discoverer = SimpleServiceDiscovery.new()
        # ノードの統計情報（ip => 統計情報）
        @stats      = SyncHash.new() {|h, k| h[k] = {} }
    end

    #@see ServiceManager#discovery_service
    def discovery_service(query, reqire=nil)
        log_trace(query)
        log_info("search query  = #{query}, reqire = #{reqire}")

        services = @discoverer.search(query, @service_list)
        if reqire
            log_debug("search result = #{services}, size = #{services.size}")
            services = select_services(services, reqire)
        end
        log_info("search result = #{services}, size = #{services.size}")
        
        EventCollector.discovery_service(query, services)
        return services
    end

    #@see ServiceManager#update_service_inner
    def update_service_inner(service_id, service_info)
        super
        log_info("service is updated. (service ID = #{service_id}, info = #{service_info})")
    end

    #@see ServiceManager#add_service
    def add_service(service)
        super
        log_info("service is added. (IP = #{service.ip}, service = #{service})")
    end

    #@see ServiceManager#delete_service
    def delete_service(service_id)
        deleted = super
        log_info("service is deleted. (service ID = #{service_id})")
        return deleted
    end

    #@see ServiceManager#update_stats
    def update_stats(ip, stats)
        update_stats_inner(ip, stats)
    end

    #@see ServiceManager#resolve_service_node
    def resolve_service_node(param)
        if @stats.size > 0
            return @stats.min_by{|k, v| v["mem_usage"]}[0]
        else
            return $ip
        end
    end

    private

    def update_stats_inner(ip, stats)
        @stats[ip] = stats
    end

    def select_services(services, reqire)
        services = services.sort_by{|service| 
            usage = @stats[service.ip]["mem_usage"]
            usage.nil?() ? 999.9 : usage
        }
        return services.shift(reqire)
    end
end

