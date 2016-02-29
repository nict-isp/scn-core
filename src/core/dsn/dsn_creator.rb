# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require 'logger'
require 'singleton'
require 'erb'

#= DSN description generating class
#
#@author NICT
#
class DSNCreator

    #@param [String] table_name        Table name
    #@param [Hash]   event_data_model  Event Data Model
    #@return[String] dsn_desc DSN description
    #@raise [ArgumentError] Required items lack of Event Data Model
    #
    def self.create_dsn(table_name, event_data_model)
        evm = EventDataModel.new(table_name)
        evm.parse(event_data_model)
        erb = ERB.new(DSN_TMPL, nil, '-')

        overlay_name = get_overlay_name(table_name, evm.user)
        return erb.result(binding), overlay_name
    end

    private

    #@param [String] table_name  Table name
    #@param [String] user_name   User name
    #@return[String] dsn_desc DSN description
    #
    def get_overlay_name(table_name, user_name)
        return "#{table_name}_#{user_name}"
    end

    #= Event Data Model interpretation class
    # It interprets the hash of Event Data Model, 
    # check essential items and generate string for replace the DSN description.
    #
    class EventDataModel

        #@return[String] User name("who")
        attr_reader    :user
        #@return[Array]  Sensor name("what")
        attr_reader    :sensors
        #@return[Array]  Filter name("where, when")
        attr_reader    :filters
        #@return[String] Table name
        attr_reader    :table

        #@param [String] table_name  Table name
        #
        def initialize(table_name)
            @table = table_name
            @filters = []
        end

        #@param [Hash] evm_hash  Hash of Even Data Model
        #@raise [ArgumentError] Required items lack of Event Data Model
        #
        def parse(evm_hash)
            if evm_hash["who"].nil?
                raise ArgumentError, "The user name is required."
            else
                @user = evm_hash["who"]
            end
            raise ArgumentError, "The sensor is required." unless evm_hash["what"].is_a?(Array)
            raise ArgumentError, "One or more sensors is required." unless evm_hash["what"].size >= 1
            @sensors = evm_hash["what"]

            if (evm_where = evm_hash["where"]).is_a?(Hash)
                @filters << filter_coordinate(evm_where)
            end

            if (evm_when = evm_hash["when"]).is_a?(Hash)
                @filters << filter_time(evm_when)
            end
        end

        #@param [Hash] evm_where  Where clause of Event Data Model
        #@raise [ArgumentError] Required items lack of Event Data Model
        #
        def filter_coordinate(evm_where)
            raise ArgumentError, "where : south has not been defined." unless (lat_min = evm_where["south"])
            raise ArgumentError, "where : north has not been defined." unless (lat_max = evm_where["north"])
            raise ArgumentError, "where : west has not been defined." unless (lon_min = evm_where["west"])
            raise ArgumentError, "where : east has not been defined." unless (lon_max = evm_where["east"])

            raise ArgumentError, "Latitude range specification is invalid.(south > north})" if (lat_min > lat_max)
            raise ArgumentError, "Longitude range specification is invalid.(west > east)"    if (lon_min > lon_max)

            return "range(latitude, #{lat_min}, #{lat_max})", "range(longitude, #{lon_min}, #{lon_max})"
        end

        #@param [Hash] evm_when   When clause of Event Data Model 
        #@raise [ArgumentError] Invalid format of Event Data Model
        #
        def filter_time(evm_when)
            raise ArgumentError, "when : start is not defined." unless (time_min = evm_when["start"])
            raise ArgumentError, "when : end is not defined." unless (time_max = evm_when["end"])
            raise ArgumentError, "Time range specification is invalid.(start > end)" if time_min > time_max

            return "range(time, \"#{time_min}\", \"#{time_max}\")"
        end
    end

    #
    # Template of DSN description
    #
    DSN_TMPL = <<-TEMPLATE
    #OVERLAY: <%= overlay_name %>
    state do
        @eventwh: discovery(category=application, type=eventwh, user=<%= evm.user -%>)
        channel: channel_eventwh, @eventwh
        <%- evm.sensors.each do |sensor| -%>
        <%- %>
        @<%= sensor -%>: discovery(category=sensor, data=<%= sensor -%>)
        scratch: scratch_<%= sensor -%>, @<%= sensor -%> => [table=<%= evm.table -%>]
        <%- end -%>
    end

    bloom do
        <%- evm.sensors.each do |sensor| -%>
        channel_eventwh <~ <%= "filter(" if evm.filters.size > 0 -%>scratch_<%= sensor -%><%= "," if evm.filters.size > 0 %>
                        <%= evm.filters.join(" && ") -%><%= ")" if evm.filters.size > 0 %>
        <%- end -%>
    end
    TEMPLATE
end

