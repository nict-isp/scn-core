#-*- codIng: utf-8 -*-
require_relative '../../utils'
require_relative './processing_factory'

#= 網内データ処理クラス
# アプリケーション要求に基づき、複数の中間処理を実行する
#
#@author NICT
#
class InNetoworkDataProcessing

    #@param [String] overlay_id オーバーレイID
    #@param [Hash] request アプリケーション要求
    #
    def initialize(request)
        @request = nil

        update_request(request)
    end

    # アプリケーション要求に基づき中間処理を再生成する。
    #
    #@param [Hash] request アプリケーション要求
    #@return [void]
    #
    def update_request(request)
        if not(request.kind_of?(Array)) || request.size < 1
            @processings = []

        elsif request != @request
            @processings = request.map { |processing| ProcessingFactory.get_instance(processing) }
        end
        log_debug() {@processings}

        @request = request
    end

    #@param [Array<Hash>] data 送信データ
    #@return [Array<Hash>] 中間処理を実行した送信データ
    #
    def execute(data)
        processed_data = @processings.inject(data) { |processing_data, processing|
            processing.execute(processing_data)
        }
        return processed_data
    end
end

