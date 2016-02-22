# -*- coding: utf-8 -*-
require 'timeout'

# Time-out time
DEFAULT_TIMEOUT = 60

# Time-out time for connection to the NPS server
TIMEOUT_TO_SERVER = DEFAULT_TIMEOUT

# Time-out time for connections with other NCP client
TIMEOUT_TO_CLIENT = DEFAULT_TIMEOUT

# Time-out time for connection to the PIAX server
TIMEOUT_TO_PAIX = DEFAULT_TIMEOUT

#= Network error
# Error sent if there is a problem with the configuration of the network.
#
#@author NICT
#
class NetworkError < StandardError; end

#= Invalid ID error
# Error sent if the requested ID to the server was invalid.
#
#@author NICT
#
class InvalidIDError < StandardError; end

#= Internal Server Error
# Error sent if an unexpected error has occurred in the server.
#
#@author NICT
#
class InternalServerError < StandardError; end

#= Application error
# Error sent if an error occurs in the application.
#
#@author NICT
#
class ApplicationError < StandardError; end

