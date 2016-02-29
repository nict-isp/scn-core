#-*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative './error_message'

module DSN

    #= Classes for intermediate encoding and result determination for the condition determination
    #
    #@author NICT
    #
    class Condition

        #@return [String] data_name  Data name
        attr_reader :data_name
        #@return [String] sign       Sign
        attr_reader :sign
        #@return [String] threshold  Threshold
        attr_reader :threshold

        #@param [String]        data_name  Data name
        #@param [String]        sign       Sign
        #@param [Array<String>] threshold  Threshold
        def initialize(name, sign, threshold)
            @data_name = name
            @sign = sign
            @threshold = threshold
        end

        # It is converted into an intermediate code.
        #
        #@param [String] expression  String of the target to be converted to an intermediate code
        #@param [String] num         Number of lines
        #
        def self.parse(expression, num)
            # Not be called directly.
            raise RuntimeError.new(ErrorMessage::ERR_INTERFACE)
        end

        # To return the intermediate code.
        #
        #@return [Hash<String,Array<String>>] Intermediate code
        #
        def to_hash()
            return {@data_name=> [@sign].concat(@threshold)}
        end

        # It determines whether or not the specified data meets the conditions.
        #
        #@param [String]        key     Data name of the target is determined conditions
        #@param [Array<String>] values  Judgment condition, threshold
        #@param [Hash<String>]  data    Hash with a data name of the condition determination target key,
        #                               and with the value of the condition determination target value.
        #@return [Boolean] If it meet the condition true, not meet the condition false
        #
        def self.ok?(key, values, data)
            # Not be called directly.
            raise RuntimeError.new(ErrorMessage::ERR_INTERFACE)
        end
    end
end
