#-*- coding: utf-8 -*-
require_relative './processing'
require_relative './merge'

#= Virtual property processing class
#
#@author NICT
#
class Virtual < Processing
    
    #@param [Hash] conditions  Intermediate processing request
    #
    def initialize(conditions = {})
        super

        update(conditions)
    end

    # To update the intermediate processing request. 
    # 
    #@param [Hash] conditions  Intermediate processing request
    #@return [void]
    #
    def update(conditions)
        @conditions = conditions

        @virtual = conditions["virtual_name"]
        @expr = conditions["virtual_expr"]
    end

    def execute(processing_data)
        # The use of each in order to exclude the value which resulted in an error.
        # If it dows not want to exclude it may be a province.
        result = []
        processing_values(processing_data, :each) { |_value_|
            begin
                log_debug {"#{_value_}"}
                # Provisional implementation that uses the eval method.
                #TODO Replace because eval is dangerous and bad performance.
                _virtual_ = nil
                _exp_     = ""
                _value_.each do |k, v|
                    case v.class.to_s
                    when "String"
                        _exp_ << "#{k} = \"#{v}\";"
                    when "Fixnum", "Float"
                        _exp_ << "#{k} = #{v};"
                    else
                        log_warn("invalid type #{v.class.to_s}")
                    end
                end
                log_debug {"#{_exp_} _virtual_ = #{@expr}"}
                eval("#{_exp_} _virtual_ = #{@expr}")
                _value_[@virtual] = _virtual_
                log_debug {"#{_value_}"}
                result << _value_

            rescue SyntaxError
                log_error("", $!)
            rescue
                log_error("", $!)
            end
        }
        return result  
    end
end

