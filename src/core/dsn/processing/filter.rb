#-*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative './processing'
require_relative '../compile/conditions'

#= Filtering processing class
#
#@author NICT
#
class Filter < Processing

    # To execute the filtering process.
    # Send only the filtering satisfy data.
    #
    #@param [Hash] processing_data  Intermediate processing data
    #@return Data was subjected to filtering(The same format as the input data)
    #
    def execute(processing_data)
        return processing_values(processing_data, :select) { |data|
            Conditions.ok?(@conditions, data)
        }
    end
end

