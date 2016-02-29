#-*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative './processing'

#= String processing class
#
#@author NICT
#
class StringOperation < Processing

    #@param [Hash] conditions  Intermediate processing request
    #
    def initialize(conditions)
        super
        @data_name = conditions["data_name"]
        @operator  = conditions["operator"]
        @param     = conditions["param"]
    end

    # To execute the string processing.
    #
    #@param [Hash] processing_data  Intermediate processing data
    #@return Data was subjected to string processing
    #
    def execute(processing_data)

        return_data = processing_data.clone()

        processing_values(return_data, :each) { |value|
            if value[@data_name].kind_of?(String)
                case @operator
                when "removeBlanks"
                    value[@data_name].gsub!("\s", "")

                when "removeSpecialChars"
                    value[@data_name].delete!(@param[0])

                when "lowerCase"
                    value[@data_name].downcase!()

                when "upperCase"
                    value[@data_name].upcase!()

                when "concat"
                    value[@data_name].concat(@param[0])

                when "alphaReduce"
                    value[@data_name].tr!("A-z", "")

                when "numReduce"
                    value[@data_name].tr!("0-9", "")

                when "replace"
                    value[@data_name].tr!(@param[0], @param[1])

                when "regexReplace"
                    value[@data_name].sub!(Regexp.new(@param[0]), @param[1])
                end
            end
        }

        return return_data
    end
end

