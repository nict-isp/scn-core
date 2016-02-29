# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative './base_method'

module DSN

    #= Discovery method class
    # To analyze the discovery method of DSN description.
    #
    #@author NICT
    #
    class DiscoveryMethod
        METHOD_NAME = "discovery"

        # To analyze the discovery syntax.
        #
        #@param [DSNText] dsn_text  Method syntax of the DSN description
        #@param [String]  num       Number of lines
        #@return [Hash<String, String|Array>] Search attribute
        #@raise [ArgumentError] Not in the correct format as a method
        #
        def self.parse(dsn_text)
            log_trace(dsn_text)

            format = nil  # format check is to implement individually.
            attributes = BaseMethod.parse(dsn_text, METHOD_NAME, format)
            log_debug(){"#{attributes}"}

            attr_hash = {}
            attributes.each do |attr|
                name, value = DSNText.split(attr.single_line, "=", 2)

                # If it can not properly separated into name and the value is an error.
                if name.nil? || value.nil?
                    raise DSNInternalFormatError, ErrorMessage::ERR_DISCOVERY_ATTR
                end
                log_debug(){"#{name}, #{value}"}

                # In the case of complex conditions, it is returned string in the array as a value.
                # For processing simplicity, use an array type even one element.
                if not attr_hash.key?(name)
                    attr_hash[name] = []
                end
                attr = attr_hash[name]

                if value[0] == "["
                    log_debug(){"#{value}"}
                    if value[-1] == "]"
                        multi_values = value[1..-2].split(",")
                        attr_hash[name].concat multi_values.map{|v| v.strip}
                    else
                        raise DSNFormatError.new(ErrorMessage::ERR_FORMAT_METHOD, dsn_text)
                    end
                else
                    log_debug(){"#{value}"}
                    attr << value
                end
            end

            attr_hash = self._multi_discovery(attr_hash)

            return attr_hash
        end

        # it determines whether or not the "discovery" syntax.
        #
        #@param [String] text String of methods
        #@return [Boolean] Match of the method
        #
        def self.is_method?(text)
            return text =~ /^#{METHOD_NAME}/
        end

        # To set the key for multiple discovery.
        #
        #@param [Hash<String, String|Array>] attr_hash  Search attribute 
        #@return [Hash<String, String|Array>] Search attribute
        #@raise [DSNFormatError] The value of the "multi" key is not an integer of 1 or more
        #
        def self._multi_discovery(attr_hash)
            if attr_hash.has_key?(KEY_MULTI)
                multi = attr_hash[KEY_MULTI][0].to_i
                if multi < 1
                    raise DSNFormatError.new(ErrorMessage::ERR_DISCOVERY_ATTR, multi)
                end
            else
                # If omitted, sets "1" by default.
                attr_hash[KEY_MULTI] = ["1"]
            end

            return attr_hash
        end
    end
end
