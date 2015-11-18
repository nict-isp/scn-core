# -*- coding: utf-8 -*-
require_relative '../utils'
require_relative './ncps_if'
require_relative './openflow/ncps_for_openflow'

#= NCPSのファクトリ兼アクセサクラス
#
#@author NICT
#
class NCPS

    class << self
        #@return [NCPS] 作成済みのNCPSインスタンス
        @@instance = nil

        # ネットワークのタイプに応じたインスタンスを生成する
        #
        #@param [String] network_type ネットワークのタイプ
        #@param [Hash] opts 起動パラメータ
        #@return [NCPS] ネットワークのタイプに応じたNCPSクライアント
        #@raise [NameError] 存在しないネットワークタイプを指定した時
        #
        def create(network_type, opts)
            if @@instance.nil?()
                case network_type
                when "OpenFlow" then
                    @@instance = NCPSForOpenFlow.new(opts)
                    #when "TCP" then
                else
                    raise NameError, "Not Supported Network #{network_type}."
                end
            end
        end

        #private

        def instance
            return @@instance
        end

        # インスタンスメソッドをクラスに委譲
        extend Forwardable
        def_delegators :instance, *NCPSInterface.instance_methods(false)
    end
end

