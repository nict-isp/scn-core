#-*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative '../../utils'
require_relative './processing'
require_relative './filter'
require_relative './cull'
require_relative './string'
require_relative './virtual'

#= Factory class of intermediate processing
#
#@author NICT
#
class ProcessingFactory

    # To create an instance of the data processing class.
    #
    #@param [Hash] processing  Intermediate processing request
    #@return [Processing] Intermediate processing class
    #
    def self.get_instance(processing)
        processing.each do |name, param|
            log_debug {"name = #{name}, param = #{param}" }

            case name
            when "filter"
                proccesing = Filter.new(param)
            when "cull_time"
                proccesing = CullTime.new(param)
            when "cull_space"
                proccesing = CullSpace.new(param)
            when "string"
                proccesing = StringOperation.new(param)
            when "virtual"
                proccesing = Virtual.new(param)

            # The following is generated directly in the inner service.
            #when "aggregate"
            #when "merge"
            else
                log_warn("undefined processing. (name=#{name})")
                proccesing = Processing.new({}) # do nothing
            end

            return proccesing   # Intermediate processing request does not have only one element.
        end
    end
end
