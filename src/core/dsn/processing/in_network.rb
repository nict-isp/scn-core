#-*- codIng: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative '../../utils'
require_relative './processing_factory'

#= In-Network data processing class
# Based on the application request, to perform multiple intermediate processing.
#
#@author NICT
#
class InNetoworkDataProcessing

    #@param [String] overlay_id  Overlay ID
    #@param [Hash]   request     Application request
    #
    def initialize(request)
        @request = nil

        update_request(request)
    end

    # To regenerate the intermediate processing on the basis of the application request.
    #
    #@param [Hash] request  Application request
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

    #@param [Array<Hash>] data  Send data
    #@return [Array<Hash>] Send data after performing the intermediate processing
    #
    def execute(data)
        processed_data = @processings.inject(data) { |processing_data, processing|
            processing.execute(processing_data)
        }
        return processed_data
    end
end

