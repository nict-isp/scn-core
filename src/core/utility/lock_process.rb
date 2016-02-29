# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative '../utils'

#= SCNミドルウェアの多重起動防止クラス
# ロックファイルの有無によってミドルウェアの起動有無をチェックする。
#
#@author NICT
#
class LockProcess

    # ロックファイルのパス
    LOCK_FILE = `hostname`.strip + "_SCN_MIDDLEWARE.lock"

    # SCNミドルウェア起動をロックする
    #
    #@return [True]  ロック成功
    #@return [False] ロック失敗(ミドルウェアが既に起動中)
    #
    def lock()
        log_trace()

        running = false

        if File.exist?(LOCK_FILE)
            pid = 0
            File.open(LOCK_FILE, "r") do |file|
                pid = file.read.chomp!.to_i
            end
            log_debug() {"exist LOCK_FILE pid = #{pid}"}

            # ロックファイルが存在した場合、そのプロセスが起動中かどうかチェックする。
            running = process_running?(pid)
            unless running
                # プロセスが起動中でなければロックファイルを一旦削除する。
                File.delete(LOCK_FILE)
            end
        end

        if running
            lock_success = false
        else
            create_lock_file()
            lock_success = true
        end

        return lock_success
    end

    # SCNミドルウェア起動のロックを解除する
    #
    #@return [void]
    #
    def unlock()
        log_trace()
        File.delete(LOCK_FILE)
    end

    private

    def process_running?(pid)
        begin
            Process.getpgid(pid)
            return true
        rescue
            return false
        end
    end

    def create_lock_file()
        File.open(LOCK_FILE, "w") do |file|
            file.puts $$
            log_debug() {"create LOCK_FILE pid = #{$$}"}
        end
    end
end
