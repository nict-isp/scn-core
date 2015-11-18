# -*- coding: utf-8 -*-
require 'singleton'
require 'json'

require_relative '../utils'
require_relative '../app_if'
require_relative './dsn_compiler'
require_relative './execution/dsn_operator'
require_relative './execution/dsn_auto_executor'

#= オーバーレイ生成クラス。
# 周期的にオーバーレイを監視し、チャネルの生成・削除・変更を行う。
#
#@author NICT
#
class DSNExecutor
    include Singleton

    def initialize()
        log_trace()
        @operators = SyncHash.new()
    end

    # 初期設定
    #
    #@param [Integer] observe_interval イベント監視の動作周期
    #@param [Integer] auto_execute_interval 自動実行の動作周期
    #@param [Integer] msg_level 応答メッセージの出力レベル
    #
    def setup(middleware_id, observe_interval, auto_execute_interval)
        log_trace(middleware_id, observe_interval, auto_execute_interval)
        EventManager.setup(observe_interval)
        DSNAutoExecutor.setup(auto_execute_interval)
    end

    # オーバーレイ生成API
    #
    #@param [String] overlay_id オーバーレイ名
    #@param [String] dsn_desc DSN記述
    #@raise [InternalServerError] 中間コードのパースに失敗した場合
    #                             (例: dsn_hash["service_links"] が無い)
    #
    def add_dsn(overlay_id, dsn_desc)
        dsn_hash = DSNCompiler.compile(dsn_desc)
        operator = DSNOperator.new(overlay_id, dsn_hash)
        # 呼び出し元へはパース終了直後に復帰する。
        # チャネル生成結果は、メッセージで通知する。
        Thread.new do
            log_time()
            begin
                operator.create_overlay()
                @operators[operator.id] = operator
            rescue
                log_error("Create overlay(#{operator.id}) failed.", $!)
            end
            log_time()
        end
    end

    # オーバーレイ削除API
    #
    #@param [String] overlay_id オーバーレイ名
    #
    def delete_dsn(overlay_id)
        operator = @operators.delete(overlay_id)
        if operator.nil?
            raise InvalidIDError, overlay_id
        end

        Thread.new do
            log_time()
            begin
                operator.delete()
            rescue
                log_error("Delete overlay(#{operator.id}) failed.", $!)
            end
            log_time()
        end
    end

    # オーバーレイ変更API
    #
    #@param [String] overlay_id オーバーレイID
    #@param [String] dsn_desc DSN記述
    #
    def modify_dsn(overlay_id, dsn_desc)
        operator = @operators[overlay_id]
        if operator.nil?
            raise InvalidIDError, overlay_id
        end
        dsn_hash = DSNCompiler.compile(dsn_desc)

        Thread.new do
            log_time()
            begin
                operator.modify_overlay(dsn_hash)
            rescue
                log_error("Modify overlay(#{operator.id}) failed.", $!)
            end
            log_time()
        end
    end

    # 周期的にオーバーレイ状態を更新する。
    #
    def update_overlay(overlay_id, event_state)
        log_time()
        begin
            operator = @operators[overlay_id]
            operator.update_overlay(event_state)
        rescue
            # オーバーレイでエラーが発生しても、
            # 他の正常なオーバーレイの実行に影響しない。
            log_error("Update overlay(#{overlay_id}) failed.", $!)
        end
        log_time()
    end

    # インスタンスメソッドをクラスに委譲
    class << self
        extend Forwardable
        def_delegators :instance, *DSNExecutor.instance_methods(false)
    end
end
