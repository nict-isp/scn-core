# -*- coding: utf-8 -*-
require 'logger'
require 'singleton'
require 'erb'

#= DSN記述生成クラス
#
#@author NICT
#
class DSNCreator

    #@param [String] table_name テーブル名
    #@param [Hash] event_data_model
    #@return[String] dsn_desc DSN記述
    #@raise [ArgumentError] イベントデータモデルの必須項目不足
    #
    def self.create_dsn(table_name, event_data_model)
        evm = EventDataModel.new(table_name)
        evm.parse(event_data_model)
        erb = ERB.new(DSN_TMPL, nil, '-')

        overlay_name = get_overlay_name(table_name, evm.user)
        return erb.result(binding), overlay_name
    end

    private

    #@param [String] table_name テーブル名
    #@param [String] user_nameユーザ名
    #@return[String] dsn_desc DSN記述
    #
    def get_overlay_name(table_name, user_name)
        return "#{table_name}_#{user_name}"
    end

    #= Event Data Model 解釈クラス
    # Event Data Model のハッシュを解釈し、
    # 必須項目のチェックとDSN記述置換用文字列生成を行う。
    #
    class EventDataModel

        #@return[String] ユーザ名("who")
        attr_reader    :user
        #@return[Array] センサ名("what")
        attr_reader    :sensors
        #@return[Array] フィルタ名("where,when")
        attr_reader    :filters
        #@return[String] テーブル名
        attr_reader    :table

        #@param [String] table_name テーブル名
        #
        def initialize(table_name)
            @table = table_name
            @filters = []
        end

        #@param [Hash] event_data_model
        #@raise [ArgumentError] イベントデータモデルの必須項目不足
        #
        def parse(evm_hash)
            if evm_hash["who"].nil?
                raise ArgumentError, "ユーザ名が必要です。"
            else
                @user = evm_hash["who"]
            end
            raise ArgumentError, "センサが必要です。" unless evm_hash["what"].is_a?(Array)
            raise ArgumentError, "１つ以上センサが必要です。" unless evm_hash["what"].size >= 1
            @sensors = evm_hash["what"]

            if (evm_where = evm_hash["where"]).is_a?(Hash)
                @filters << filter_coordinate(evm_where)
            end

            if (evm_when = evm_hash["when"]).is_a?(Hash)
                @filters << filter_time(evm_when)
            end
        end

        #@param [Hash] where
        #@raise [ArgumentError] イベントデータモデルの必須項目不足
        #
        def filter_coordinate(evm_where)
            raise ArgumentError, "where : south が定義されていません。" unless (lat_min = evm_where["south"])
            raise ArgumentError, "where : north が定義されていません。" unless (lat_max = evm_where["north"])
            raise ArgumentError, "where : west が定義されていません。" unless (lon_min = evm_where["west"])
            raise ArgumentError, "where : east が定義されていません。" unless (lon_max = evm_where["east"])

            raise ArgumentError, "緯度範囲指定が不正です。(south > north})" if (lat_min > lat_max)
            raise ArgumentError, "経度範囲指定が不正です。(west > east)"    if (lon_min > lon_max)

            return "range(latitude, #{lat_min}, #{lat_max})", "range(longitude, #{lon_min}, #{lon_max})"
        end

        #@param [Hash] when
        #@raise [ArgumentError] イベントデータモデルの書式不正
        #
        def filter_time(evm_when)
            raise ArgumentError, "when : start が定義されていません。" unless (time_min = evm_when["start"])
            raise ArgumentError, "when : end が定義されていません。" unless (time_max = evm_when["end"])
            raise ArgumentError, "時刻範囲指定が不正です(start > end)。" if time_min > time_max

            return "range(time, \"#{time_min}\", \"#{time_max}\")"
        end
    end

    #
    # DSN記述テンプレート
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

