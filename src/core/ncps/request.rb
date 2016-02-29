# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative '../utils'

#= 同期通信管理クラス
#@author NICT
#
class Request

    def initialize()
        @req_id   = 0
        @requests = Hash.new()
    end

    # 非同期処理からのレスポンスを同期で受け取る
    #
    #@yield [req_id, request] 非同期処理を実行するブロック
    #@yieldparam [Integer]   req_id  リクエストのID
    #@yieldparam [Semaphore] request リクエストのセマフォ
    #@return リクエストへのレスポンス
    #
    def get_result()
        req_id, request = get_request()
        yield(req_id, request)
        result = request.acquire() #同期で待ち合せ
        del_request(req_id)

        return result
    end

    # 非同期処理からの複数のレスポンスを同期で受け取る
    #
    #@param [Integer] req_size 待ち合せるレスポンスの数
    #@yield [req_id, request] 非同期処理を実行するブロック
    #@yieldparam [Integer]   req_id  リクエストのID
    #@yieldparam [Semaphore] request リクエストのセマフォ
    #@return [Array] リクエストへのレスポンスの一覧
    #
    def get_results(req_size)
        req_id, request = get_request()
        results = request.results()
        begin
            yield(req_id, request)
            request.acquire(req_size) #同期で待ち合せ
        rescue
            log_warn("#{req_size} request but #{results.size} response.")
        end
        del_request(req_id)

        return results
    end

    # リクエストへのレスポンスを返却する
    #
    #@param [Integer] req_id 応答するリクエストのID
    #@param [Hash] resp 応答結果
    #@return [Array] ダミーデータ（通常使用しない。）
    #
    def response(req_id, resp)
        #log_debug() {resp}
        @requests[req_id].release(resp)
        []
    end

    private

    # リクエストに使用するIDとセマフォを生成する。
    #
    def get_request()
        @req_id += 1
        req_id = @req_id.to_s()
        @requests[req_id] = Semaphore.new()
        return req_id, @requests[req_id]
    end

    # リクエストIDのセマフォを削除する。
    #
    def del_request(req_id)
        @requests.delete(req_id)
    end
end

