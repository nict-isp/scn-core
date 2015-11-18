# -*- coding: utf-8 -*-
require 'singleton'

require_relative '../utils'

#= ノードの資源情報収集クラス
# Linuxからノードの資源情報を収集する。
#
#@author NICT
#
class NodeResourceCollector
    include Singleton

    def initialize()
        @node_resource  = Hash.new()
        @node_resource["cpu_clock"] = get_cpu_clock()
        @node_resource["cpu_usage"] = 0
        @node_resource["mem_total"] = get_mem_total()
        @node_resource["mem_free"]  = 0
        @node_resource["mem_usage"] = 0

        @cpu_stat_old  = Array.new(4, 0)
    end

    # 資源情報を更新する。
    #
    #@return [NodeResource]  ノードの資源情報
    #
    def update()
        @node_resource["cpu_usage"] = get_cpu_usage()
        @node_resource["mem_free"]  = get_mem_free()
        if @node_resource["mem_total"]
            free = (@node_resource["mem_free"].to_f / @node_resource["mem_total"]) * 100.0
            @node_resource["mem_usage"] = (100.0 - free).round(2)
        else
            @node_resource["mem_usage"] = 0.0
        end
        return @node_resource
    end

    private

    # CPUのクロック数を取得する。
    #
    #@return [Array<Integer>]  CPUのクロック数(MHz)
    #
    def get_cpu_clock()
        cpu_clock = Array.new
        open("/proc/cpuinfo", "r") { |info|
            while line = info.gets
                data = line.chomp.split(/\s+/) # 空白で区切る
                if data.length >= 4
                    if data[0] == "cpu" and data[1] == "MHz"
                        cpu_clock << data[3].to_i
                    end
                end
            end
        }

        return cpu_clock
    end

    # メモリサイズを取得する。
    #
    #@return [Integer]  メモリサイズ(KB)
    #
    def get_mem_total()
        mem_total = nil
        open("/proc/meminfo", "r") { |info|
            while line = info.gets
                data = line.chomp.split(/\s+/) # 空白で区切る
                if data.length >= 2
                    if data[0] == "MemTotal:"
                        mem_total = data[1].to_i
                    end
                end
            end
        }

        return mem_total
    end

    # CPU使用率を取得する。
    # 取得手順は、以下の通り。
    #   (1) /proc/statの各値を取る。
    #   (2) 前回取得した各値のすべての値について差分を求める。
    #   (3) (2)で求めた各値の合計を求める。
    #   (4) (2)の各値 / (3)で求めた合計を計算する。
    #@return [Float]  CPU使用率(%)
    #
    def get_cpu_usage()
        # /proc/stat から、各種状態で消費された cpu 時間を取得する。
        # /proc/stat からは、以下の情報が取得できる。
        #   (1)  user       : ユーザーモードで消費した時間。
        #   (2)  nice       : 低い優先度 (nice) のユーザーモードで消費した時間。
        #   (3)  system     : システムモードで消費した時間。
        #   (4)  idle       : タスク待ち (idle task) で消費した時間。
        #   (5)  iowait     : I/O の完了待ちの時間。 (Linux 2.5.41 以降)
        #   (6)  irq        : 割り込みの処理に使った時間。(Linux 2.6.0-test4 以降)
        #   (7)  softirq    : ソフト割り込みの処理に使った時間。(Linux 2.6.0-test4 以降)
        #   (8)  steal      : 盗まれた時間 (stolen time)。仮想化環境での動作時に他のオペレーティングシステムにより消費された時間である。(Linux 2.6.11 以降)
        #   (9)  guest      : Linux カーネルの制御下のゲストオペレーティングシステムの仮想 CPU の 実行に消費された時間。(Linux 2.6.24 以降)
        #   (10) guest_nice : nice が適用されたゲスト (Linux カーネルの制御下のゲストオペレーティングシステムの仮想 CPU) の 実行に消費された時間。(Linux 2.6.33 以降)
        cpu_stat_now = Array.new()
        open("/proc/stat", "r") { |info|
            while line = info.gets
                data = line.chomp.split(/\s+/) # 空白で区切る
                if data.length >= 5
                    if data[0] == "cpu"
                        data.delete_at(0)
                        data.each { |item|
                            cpu_stat_now << item.to_i
                        }
                    end
                end
            end
        }

        idle = 0
        if cpu_stat_now.length >= 10
            # 前回取得した cpu 時間との差分を取得する。
            cpu_stat_sub = Array.new()
            @cpu_stat_old.each_index { |i|
                cpu_stat_sub << (cpu_stat_now[i] - @cpu_stat_old[i])
            }

            # cpu の idle 率を計算する。
            total = cpu_stat_sub.inject(:+) # 配列の合計を算出
            if total > 0
                idle  = 1.0 * cpu_stat_sub[3] / total * 100.0
            end

            @cpu_stat_old = cpu_stat_now
        end

        return (100.0 - idle).round(2)
    end

    # 未使用メモリサイズを取得する。
    #
    #@return [Integer]  メモリサイズ(KB)
    #
    def get_mem_free()
        mem_free  = nil
        open("/proc/meminfo", "r") { |info|
            while line = info.gets
                data = line.chomp.split(/\s+/) # 空白で区切る
                if data.length >= 2
                    if data[0] == "MemFree:"
                        mem_free = data[1].to_i
                    end
                end
            end
        }

        return mem_free
    end

    # インスタンスメソッドをクラスに委譲
    class << self
        extend Forwardable
        def_delegators :instance, *NodeResourceCollector.instance_methods(false)
    end
end
