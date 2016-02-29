#-*- codIng: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative '../../utils'
require_relative '../../utility/m2m_format'
require_relative '../compile/communication_data'

#= Intermediate processing class at the time of data transmission and reception
# To execute the extraction process to the data.
#
#@author NICT
#
class OnNodeProcessing

    #@param [String]  overlay_id  Overlay ID
    #@param [Service] service     Information of service to perform the intermediate processing
    #@param [Hash]    request     Application request
    #
    def initialize(service, request)
        @service = service
        @request = nil

        update_request(request)
    end

    # To regenerate the intermediate processing on the basis of the application request.
    #
    #@param [Hash] request  Application request
    #@return [void]
    #
    def update_request(request)
        if not(request.kind_of?(Array))
            @selects = {}

        elsif request != @request
            service_info = @service.info["data"] || {}
            @selects = request.inject({}) { |hash, select|
                hash[select["name"]] = DSN::CommunicationData.from_hash(select, service_info)
                hash
            }
        end
        log_debug() {@selects}

        @request = request
    rescue
        log_error("", $!)
    end

    # To execute the information extraction. (Destructive operation)
    #
    # To delete the information that has not been specified the data name.
    # Does nothing if the specified data name was not even one.
    #
    # In the case of M2M data, it is modified to suit also the schema of the meta-information.
    # In the case of M2M data, required information (latitude, longitude, altitude, and time) do not want to delete.
    #
    #@param [Hash] data  Data for the information extraction
    #@return [Hash] Data after the information extraction
    #
    def execute(data)
        extracts = @selects.keys()
        if extracts.size > 0
            if M2MFormat.formatted?(data)
                data = M2MFormat.convert_current_format(data)
                extracts |= ["latitude", "longitude", "altitude", "time"]
                M2MFormat.extract_schema(data, extracts)
                extracted = M2MFormat.get_values(data).map { |value|
                    extracts.inject({}){ |hash, key| hash[key] = value[key]; hash }
                }
                M2MFormat.set_values(data, extracted)
            else
                data = data.map { |value|
                    extracts.inject({}){ |hash, key| hash[key] = value[key]; hash }
                }
            end
        end
        return data
    end
end

