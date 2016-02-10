# -*- coding: utf-8 -*-
require 'singleton'
require 'forwardable'

require_relative '../utils'
require_relative '../utility/message'
require_relative './service_manager'
require_relative './overlay_manager'
require_relative '../ncps/ncps'

#= スーパーバイザクラス
# 他レイヤからの要求をTranslatorの各機能へ振り分ける。
#
#@author NICT
#
class Supervisor
    include Singleton
    include Message
    extend  Forwardable

    def_delegators :@service_manager, :join_service, :update_service, :leave_service, :discovery_service, :set_service
    def_delegators :@service_manager, :update_stats, :resolve_service_node
    def_delegators :@overlay_manager, :create_overlay, :delete_overlay
    def_delegators :@overlay_manager, :get_channel, :create_channel, :delete_channel, :update_channel, :activate_channel, :inactivate_channel
    def_delegators :@overlay_manager, :get_overlay, :get_overlays_by_service_id, :update_overlays_by_service
    def_delegators :@overlay_manager, :set_trigger, :set_merge, :send_message
    def_delegators :@processing_manager, :send_data, :receive_data

    #@return [ServiceManager]
    attr_reader :service_manager

    #@return [OverlayManager]
    attr_reader :overlay_manager

    #@return [ProcessingManager]
    attr_reader :processing_manager

    def initialize()
        log_trace()
        @lock = Mutex.new()
    end

    # 初期設定
    #
    #@param [String] middleware_id ミドルウェアID
    #@param [String] service_server サービスサーバーのIP
    #@param [Integer] supervise Supervisorの動作周期
    #@param [Integer] propagate Propagateの動作周期
    #@return [void]
    #
    def setup(middleware_id, service_server)
        log_trace(middleware_id, service_server)

        @middleware_id      = middleware_id
        @service_manager    = ServiceManager.create(middleware_id, service_server)
        @overlay_manager    = OverlayManager.new(middleware_id)
        @processing_manager = ProcessingManager.instance
    end

    # 他ノードからのリクエストを処理する
    #
    #@param [String] message リクエストメッセージ
    #@return [String] レスポンスメッセージ
    #
    def receive_request(message)
        log_trace()
        response = nil
        begin
            #@lock.synchronize {
                type, method_name, args = decode_message(message)
                log_trace(type, method_name, args)

                case type
                when REQUEST_SUPERVISOR
                    response = self.method(method_name).call(*args)
                when REQUEST_SERVICE_MANAGER
                    response = @service_manager.method(method_name).call(*args)
                when REQUEST_OVERLAY_MANAGER
                    response = @overlay_manager.method(method_name).call(*args)
                when REQUEST_DSN_EXECUTOR
                    response = DSNExecutor.method(method_name).call(*args)
                else
                    log_warn("invalid message: type = #{type}, method_name = #{method_name}, args = #{args}")
                end
            #}
        rescue
            log_error("failed to response", $!)
        end

        return encode_message(response)
    end

    # メッセージタイプに応じて、対応するメソッドを呼び出す。
    #
    #@param [JSON] message 他SCNからのメッセージ
    #@return [void]
    #
    def receive_propagate(message)
        log_trace()
        begin
            #@lock.synchronize {
                type, method_name, args = decode_message(message)
                log_trace(type, method_name, args)

                case type
                when PROPAGATE_SUPERVISOR
                    self.method(method_name).call(*args)
                when PROPAGATE_SERVICE_MANAGER
                    @service_manager.method(method_name).call(*args)
                when PROPAGATE_OVERLAY_MANAGER
                    @overlay_manager.method(method_name).call(*args)
                when PROPAGATE_DSN_EXECUTOR
                    DSNExecutor.method(method_name).call(*args)
                else
                    log_warn("invalid message: type = #{type}, method_name = #{method_name}, args = #{args}")
                end
            #}
        rescue
            log_error("failed to propagte", $!)
        end

        return nil
    end

    # ネットワークレイヤで要求を満たせなかったパスの通知を受ける
    #
    #@param [Array<String>] path_ids 要求を満たせないパスIDのリスト
    #@return [void]
    #
    def notify_violation(path_ids)
        log_debug{"violation path ID: #{path_ids.join(", ")}"}

        #TODO パスの再生成依頼は可能だが、再生成で改善するための仕組みがない
    end

    # インスタンスメソッドをクラスに委譲
    class << self
        extend Forwardable
        def_delegators :instance, *Supervisor.instance_methods(false)
    end
end

