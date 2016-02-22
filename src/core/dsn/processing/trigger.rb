#-*- coding: utf-8 -*-
require_relative '../compile/conditions'

#= State monitoring class
#
#@author NICT
#
class Events

    #@param [Hash] app_request  State monitoring request
    #@example Examples of state monitoring request
    #{
    #   "event_name1" => {}, # Event information. For more information, see Event#initialize(app_request).
    #   "event_name2" => {},
    #       :
    #}
    #
    def initialize(app_request)
        @events      = {}
        @app_request = {}

        update_request(app_request)
    end

    # To generate an event class for each event name.
    #
    #@param [Hash] app_request  State monitoring request
    #@return [void]
    #
    def update_request(app_request)
        if @app_request != app_request
            log_debug() { "update request = #{app_request}" }

            app_request.each do |event_name, request|
                event = @events[event_name]
                if event.nil?
                    @events[event_name] = Event.new(request)
                else
                    event.update_request(request)
                end
            end

            # To remove the old event.
            (@events.keys - app_request.keys).each do |event_name|
                @events.delete(event_name)
            end

            @app_request = app_request
        end
    end

    # To ask the state monitoring in each event class
    #
    #@param [String]               channel  Channel name
    #@param [Hash<String, Object>] data     Data after the information extraction process
    #@return [void]
    #
    def observe(channel, data)
        log_trace(channel, data)
        @events.each{ |event_name, event| event.observe(channel, data) }
    end

    # To get the firing event
    #
    #@param [Hash<String, Nil>] channles  Channel to be monitored
    #@param [Float]             time      Elapsed time from the previous
    #@return [Hash<String, Boolean>] Event name and on/off state of firing events(When on, true)
    #
    def get_fire_event(channels, time)
        events = {}
        @events.each do |event_name, event|
            fire, status_on = event.fire?(channels, time)
            events[event_name] = status_on if fire
        end
        return events
    end

    # To set the firing state of the event
    #
    #@param [Hash<String, Boolean>] events  Event name and on/off state of firing events(When on, true)
    #@return [void]
    #
    def set_fire_event(events)
        events.each do |event_name, status_on|
            event = @events[event_name]
            if not(event.nil?)
                event.set_status_on(status_on)
            end
        end
    end

    # For interface to retrieve the event state
    #
    #@return [Hash] Event state
    #@example
    #{
    #   "event_name1" => {},     # Event information. For more information, see Event#to_hash().
    #   "event_name2" => {},
    #       ：
    #}
    #
    def to_hash()
        return @events.inject({}){|hash, (event_name, event)| hash[event_name] = event.to_hash(); hash}
    end
end

#= Class that manages events of the state and the ignition
#
#@author NICT
#
class Event

    #@param [Hash] app_request  State monitoring request
    #@example Example of state monitoring request
    #{
    #   "on"      => []              # Conditions for the event to on. For more information, see Trigger class.
    #   "off"     => []              # Conditions for the event to off. For more information, see Trigger class.
    #   "channel" => "channel_name1" # Channel name to be monitored
    #}
    #
    def initialize(app_request)
        @triggers    = {true => [], false => []}
        @status_on   = false
        @app_request = {}

        update_request(app_request)
    end

    # From the application request, and generates a trigger class
    #
    #@param [Hash] app_request  State monitoring request
    #@return [void]
    #
    def update_request(app_request)
        log_debug() { app_request }

        if @app_request != app_request
            # If there is a change, even a little, re-create the instance.
            #
            @status_on       = app_request["state"] | false
            @triggers[true]  = app_request["off"].map{ |request| Trigger.new(request) }
            @triggers[false] = app_request["on"].map{ |request| Trigger.new(request) }

            @app_request = app_request
            reset()
        end
    end

    # To notify the data reception in each trigger class.
    #
    #@param [String]      channel    Channel name
    #@param [Array<Hash>] data_list  Received data
    #@return [void]
    #
    def observe(channel, data_list)
        log_trace(channel, data_list)
        @triggers[@status_on].each{ |trigger| trigger.observe(channel, data_list) }
    end

    # To get the firing state of the event
    #
    #@param [Hash<String, Nil>] channles  Channel to be monitored
    #@param [Float]             time      Elapsed time from the previous
    #@return [Boolean, Boolean] When the event is fired, true. Event name and the on/off state. (When on, true)
    #
    def fire?(channles, time)
        if @triggers[@status_on].any? { |trigger| trigger.fire?(channles, time) }
            @status_on = (not (@status_on))
            reset()

            result = true
        else
            result = false
        end
        return result, @status_on
    end

    # To set the on/off state of the event
    #
    #@param [Boolean] status_on  Event state (when on, true)
    #@return [void]
    #
    def set_status_on(status_on)
        if @status_on != status_on
            @status_on = status_on
            reset()
        end
    end

    # To reset the state of the trigger
    #
    #@return [void]
    #
    def reset()
        @triggers[@status_on].each{ |trigger| trigger.reset() }
    end

    # For interface to retrieve the event state
    #
    #@return [True]  Event on
    #@return [False] Event off
    #
    def to_hash()
        return @status_on
    end
end

#= Class that determines the firing of event
#
#@author NICT
#
class Trigger

    #@param [Hash] app_request  State monitoring request
    #@example Example of state monitoring request
    #{
    #   "trigger_interval" => 10,   # Firing cycle.
    #   "trigger_conditions" => {   # Firing condition. For more information, see Condition class.
    #       "count" => [">=", 10]
    #   },
    #   "conditions" => {           # Data to be monitored. For more information, see Condition class.
    #       "rain" => [">=", 25.0]
    #   },
    #}
    #
    def initialize(app_request)
        log_debug() { app_request }

        @channel           = app_request["channel"]
        @condition         = app_request["conditions"]
        @trigger_condition = app_request["trigger_conditions"]
        @trigger_interval  = app_request["trigger_interval"]

        reset()
    end

    # To run the state monitoring
    #
    #@param [String]      channel    Channel name
    #@param [Array<Hash>] data_list  Received data
    #@return [void]
    #
    def observe(channel, data_list)
        if @channel == channel
            log_trace(channel, data_list)
            @count += data_list.select{|data| DSN::Conditions.ok?(@condition, data)}.size
        end
        log_debug{"count #{@count}"}
    end

    # To get the firing state of the trigger
    #
    #@param [Hash<String, Nil>] channles  Channel to be monitored
    #@param [Float]             time      Elapsed time from the previous
    #@return [Boolean] When the event is fired, true
    #
    def fire?(channles, time)
        result = false
        if channles.include?(@channel)
            @time += time
            if @time >= @trigger_interval
                result = DSN::Conditions.ok?(@trigger_condition, {"count" => @count})
                reset()
            end
        else
            reset()
        end
        return result
    end

    # To reset the state of the trigger.
    #
    #@return [void]
    #
    def reset()
        @count = 0
        @time = 0
    end
end

