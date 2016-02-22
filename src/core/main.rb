# -*- coding: utf-8 -*-
require_relative './utils'
require_relative './utility/lock_process'
require_relative './manager'

# Entry point of the program
# How to Start:
# $ ruby main.rb <em>IP address of the local node/subnet mask</em>
#
#@author NICT
#
USAGE = "\nusage:\n  main.rb IPAddress/SubnetMask"

if ARGV.count < 1
    log_fatal(USAGE)
else
    my_ipaddress = ARGV[0]

    log_trace
    # To check the IP address.
    if set_ipaddress_ok?(my_ipaddress)
        array = my_ipaddress.split("/")

        # To prevent multiple start-up of SCN middleware.
        lock_process = LockProcess.new()
        if lock_process.lock()
            if ARGV.count == 2
                default_id = ARGV[1] # This argument is used only at the time of the test.
            else
                default_id = nil
            end
            manager = SCNManager.new()
            manager.setup(array[0], array[1], default_id)
            manager.start()

            ########################################
            # Until it stops, it is here blocked.  #
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
