# -*- coding: utf-8 -*-
require_relative '../utils'

#= セマフォクラス
# 非同期処理を同期するためのセマフォの機能を提供する。
#
#@example 単一の処理を待ち合せる例
#    semaphore = Semaphore.new
#    async_method(semaphore.get_callback())  #非同期処理の結果をコールバックで受け取る
#    result = semaphore.acquire              #結果を同期で待ち合せ
#
#@example 複数の処理を待ち合せる例
#    semaphore = Semaphore.new
#    async_method(semaphore.get_callback())  #非同期処理の結果をコールバックで受け取る
#    async_method(semaphore.get_callback())  #非同期処理の結果をコールバックで受け取る
#    results = semaphore.acquire(2)          #結果を同期で待ち合せ
#
#@example 非同期処理の例
#    def async_method(callback)
#        Thread.new {
#            sleep(5)
#              :
#            callback.call(result)  #コールバックへレスポンスを返却する。
#        }
#    end
#
#@author NICT
#
class Semaphore

    #@return セマフォ処理でブロックした処理の結果の配列
    attr_reader :results

    #
    def initialize()
        @results = []
    end

    # 資源を獲得する。
    # 要求した資源数を獲得できるまでスレッドをブロックする。
    #
    #@param [Integer] request 要求する資源数
    #@param [Integer] time 最大待ち時間(ms)
    #@return [Object] if request == 1 資源解放時の戻り値
    #@return [Array<Object>] if request >  1 資源解放時の戻り値の配列
    #@raise [Timeout::Error] 最大待ち時間に達しても要求した資源が獲得できなかった場合
    #
    def acquire(request = 1, time = DEFAULT_TIMEOUT)
        timeout(time) do
            Signal.trap(:INT){ raise Interrupt }
            while (@results.size < request)
                sleep(0.1)
            end
        end
        return (if request == 1; result() else @results end)
    end

    #@attribute [r] result
    #@return [Object] セマフォ処理でブロックした処理の結果（先頭要素のみ）
    #
    def result()
        results_size = @results.size()
        raise RangeError, "too many results. (=#{results_size})" if results_size > 1
        return (if results_size > 0; @results[0] else nil end)
    end

    # 資源を解放する。
    # 資源解放時の戻り値は資源獲得時の戻り値として取得できる
    #
    #@param result 資源解放時の戻り値
    #@return [void]
    #
    def release(result = nil)
        @results << result
    end

    #@return [Callable] 第一引数を資源解放時の戻り値として引き渡すコールバック
    #
    def get_callback()
        return Proc.new { |result| release(result) }
    end
end

