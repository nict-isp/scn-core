# -*- coding: utf-8 -*-
require 'singleton'
require 'json'

require_relative '../utils'
require_relative '../app_if'
require_relative './dsn_compiler'
require_relative './execution/dsn_operator'
require_relative './execution/dsn_auto_executor'

#= Overlay execution class.
# Periodically monitor the overlay, it create, delete, and change a channel.
#
#@author NICT
#
class DSNExecutor
    include Singleton

    def initialize()
        log_trace()
        @operators = SyncHash.new()
    end

    # Initial setting
    #
    #@param [Integer] observe_interval       The operation period of the event monitoring
    #@param [Integer] auto_execute_interval  The operation period of the automatic execution
    #@param [Integer] msg_level              The output level of the response message
    #
    def setup(middleware_id, observe_interval, auto_execute_interval)
        log_trace(middleware_id, observe_interval, auto_execute_interval)
        EventManager.setup(observe_interval)
        DSNAutoExecutor.setup(auto_execute_interval)
    end

    # API for overlay to generate
    #
    #@param [String] overlay_id  Overlay name
    #@param [String] dsn_desc    DSN description
    #@raise [InternalServerError] It failed to analysis of intermediate code
    #                             (example: dsn_hash["service_links"] is nothing)
    #
    def add_dsn(overlay_id, dsn_desc)
        dsn_hash = DSNCompiler.compile(dsn_desc)
        operator = DSNOperator.new(overlay_id, dsn_hash)
        # It is to the caller to return immediately after the end of the analysis.
        # Channel generation results are notified by a message.
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

    # API for overlay to delete
    #
    #@param [String] overlay_id  Overlay ID
    #
    def delete_dsn(overlay_id)
        operator = @operators.delete(overlay_id)
        if operator.nil?
            raise InvalidIDError, overlay_id
        end

        # Removing channel and the like is performed in Translator.
    end

    # API for overlay to modify
    #
    #@param [String] overlay_id  Overlay ID
    #@param [String] dsn_desc    DSN description
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

    # Periodically update the overlay state.
    #
    #@param [String] overlay_id   Overlay ID
    #@param [Hash]   event_state  Event state
    #
    def update_overlay(overlay_id, event_state)
        log_time()
        begin
            operator = @operators[overlay_id]
            operator.update_overlay(event_state)
        rescue
            # Even if an error occurs in the overlay, 
            # it does not affect the execution of other normal overlay.
            log_error("Update overlay(#{overlay_id}) failed.", $!)
        end
        log_time()
    end

    # Delegate instance method to class
    class << self
        extend Forwardable
        def_delegators :instance, *DSNExecutor.instance_methods(false)
    end
end
