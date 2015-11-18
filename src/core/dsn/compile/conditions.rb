#-*- coding: utf-8 -*-
require_relative '../../utils'
require_relative './condition_factory'
require_relative './dsn_text'

module DSN

    #=condtions構文の解析をおこなう。
    #
    #@author NICT
    #
    class Conditions

        #@param [DSNText] expression 対象の文字列
        #@param [Array<String>] and and構文で接続される文字列
        #@param [Array<String>] or or構文で接続される文字列
        #@param [String] condtion and,orで接続される最終的な条件
        #
        def initialize(expression)
            @expression = expression
            @and        = []
            @or         = []
            @condition  = nil
        end

        #文字列からインスタンスを生成する。
        #
        #@param [DSNText] 対象の文字列
        #@return [Conditions] Conditionsクラスのインスタンス
        #
        def self.parse(expression)
            condition = Conditions.new(expression)
            condition._parse()
            return condition
        end

        #文字列からインスタンスを生成するための内部処理
        def _parse()

            # |または&で文字列分割ができた場合はreturn
            @or = _split_conditions("||")
            return if @or.size > 0

            @and = _split_conditions("&&")
            return if @and.size > 0

            # 分割できず文字列全体が括弧で囲まれていた場合は
            # 括弧を外して再度分割処理
            if(/^\(.*\)$/ =~ @expression.single_line)
                _trim_brackets()
                _parse()
            else

                # 単一の条件式まで分割済み
                @condition = ConditionFactory.parse(@expression)
            end
        end

        #条件式の分割処理
        #
        #@param [String] sign 分割条件の符号( & or | )
        #@return [Array<Conditions>] Condtionsインスタンスの配列
        #
        def _split_conditions(sign)
            conditions = []

            log_debug{"in:" + @expression.single_line}
            #            expressions = split_conditions(@expression.single_line, sign).map{|cond|
            expressions = DSNText.split(@expression.single_line, sign).map{|cond|
                log_debug{"out:" + cond}
                DSNText.new(@expression.text, @expression.line_offset, cond)
            }
            # 条件が分割されない場合は、引数の符号に該当するものなし。
            if expressions.length == 1
                return conditions
            end

            expressions.each do |expression|
                # 単一の条件式になるまで再帰呼び出し
                conditions << Conditions.parse(expression)
            end
            return conditions
        end

        #行頭と末尾のかっこを削除する処理
        def _trim_brackets()
            log_debug(){"#{@expression.single_line}"}
            reg = /^\((?<exp>.+)\)$/.match(@expression.single_line)
            log_debug(){"#{reg}"}
            if reg.nil? == true
                return
            else
                @expression = DSNText.new(@expression.text, @expression.line_offset, reg[:exp])
            end
        end

        #中間コードに変換する処理
        #
        #@return [Hash<String,Object>] 条件式の中間コード
        #
        def to_hash()
            return {"-or"  => @or.map{ |condition| condition.to_hash() }}   if @or.size > 0
            return {"-and" => @and.map{ |condition| condition.to_hash() }}  if @and.size > 0
            return @condition.to_hash
        end

        #条件式で使用されるすべてのデータ名を取得する処理
        #
        #@return [Array<String>] 条件式中のデータ名
        #
        def get_data_names()
            return @or.inject([]){ |parent, condition| parent.concat condition.get_data_names } if @or.size > 0
            return @and.inject([]){ |parent, condition| parent.concat condition.get_data_names }  if @and.size > 0
            return [@condition.data_name]
        end

        #引数で指定したデータが条件式を満たしているかどうかを判定する。
        #
        #@param [Condtions] 判定対象の条件式
        #@param [Hash<String,String>] 判定対象のデータ
        #@return [Boolean] 条件を満たしていた場合true,満たしていない場合false
        #
        def self.ok?(conditions, data)
            conditions.each do |key, values|
                case key
                when "-and"
                    result = values.all?{ |condition| self.ok?(condition, data) }
                when "-or"
                    result = values.any?{ |condition| self.ok?(condition, data) }
                else
                    result = ConditionFactory.ok?(key, values, data)
                end
                log_debug() { "conditions = #{conditions}, data = #{data}, result = #{result}" }

                return result   # 条件式のHashは1要素しか持たない
            end
        end
    end
end
