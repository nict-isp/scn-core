# -*- coding: utf-8 -*-
require_relative './utils'
require_relative './utility/lock_process'
require_relative './manager'

# プログラムのエントリポイント
# 起動方法:
# $ ruby main.rb <em>自ノードのIPアドレス/サブネットマスク</em>
#
#@author NICT
#
USAGE = "\nusage:\n  main.rb IPAddress/SubnetMask"

if ARGV.count < 1
    log_fatal(USAGE)
else
    my_ipaddress = ARGV[0]

    log_trace
    # IPアドレスをチェックする。
    if set_ipaddress_ok?(my_ipaddress)
        array = my_ipaddress.split("/")

        # SCNミドルウェアの多重起動を防止する。
        lock_process = LockProcess.new()
        if lock_process.lock()
            if ARGV.count == 2
                default_id = ARGV[1] # この引数は、テスト時のみ使用する。
            else
                default_id = nil
            end
            manager = SCNManager.new()
            manager.setup(array[0], array[1], default_id)
            manager.start()

            ########################################
            # stop するまで、ここでブロックされる。#
            ########################################
            lock_process.unlock()

            log_info("SCN Manager stop.")
        else
            log_fatal("SCN middleware is already running.")
        end
    else
        log_fatal("IPAddress(=#{my_ipaddress}) is invalid." + USAGE)
    end
end
