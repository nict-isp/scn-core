#-*- coding: utf-8 -*-
require_relative './processing'
require_relative './merge'

#= 仮想プロパティ処理クラス
#
#@author NICT
#
class Virtual < Processing
    
    #@param [Hash] conditions 中間処理要求
    #
    def initialize(conditions = {})
        super

        update(conditions)
    end

    # 中間処理要求を更新する。 
    # 
    #@param [Hash] conditions 中間処理要求
    #@return [void]
    #
    def update(conditions)
        @conditions = conditions

        @virtual = conditions["virtual_name"]
        @expr = conditions["virtual_expr"]
    end

    def execute(processing_data)
        # エラーになった値を弾くためにeachを使用
        # 弾かない場合はmapで良い
        result = []
        processing_values(processing_data, :each) { |_value_|
            begin
                log_debug {"#{_value_}"}
                # evalメソッドを使用する仮実装
                #TODO evalは危険＆パフォーマンスが悪いので置き換える
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

