#-*- coding: utf-8 -*-
require_relative './error_message'

module DSN

    #= 条件判定についての中間コード化および結果判定をおこなうクラス。
    #
    #@author NICT
    #
    class Condition

        #@return [String] name データ名
        attr_reader :data_name
        #@return [String] sign 符号
        attr_reader :sign
        #@return [String] threshold 閾値
        attr_reader :threshold

        #@param [String] data_name:データ名 
        #@param [String] sign :判定条件
        #@param [Array<String>] threshold:閾値 #
        def initialize(name, sign, threshold)
            @data_name = name
            @sign = sign
            @threshold = threshold
        end

        #中間コードに変換する。
        #
        #@param [String] expression 中間コードに変換する対象の文字列
        #@param [String] num 行数
        #
        def self.parse(expression, num)
            #直接呼び出さない
            raise RuntimeError.new(ErrorMessage::ERR_INTERFACE)
        end

        #中間コードを返却する。
        #
        #@return [Hash<String,Array<String>>] 中間コード
        #
        def to_hash()
            return {@data_name=> [@sign].concat(@threshold)}
        end

        #指定したデータが条件を満たしているかどうかを判定する。
        #
        #@param [String] key 条件判定対象のデータ名
        #@param [Array<String>] 判定条件, 閾値
        #@param [Hash<String>] 条件判定対象のデータ名をキーに、値として、条件判定対象の値を持つハッシュ。 
        #@return [Boolean] 判定条件を満たしている場合は、true,満たしていない場合はfalse
        #
        def self.ok?(key, values, data)
            #直接呼び出さない
            raise RuntimeError.new(ErrorMessage::ERR_INTERFACE)
        end
    end

end
