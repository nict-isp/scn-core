# -*- coding: utf-8 -*-
require_relative './base_method'
require_relative './conditions'

module DSN

    #= MetaMethodメソッドクラス
    # DSN記述のmetaメソッドを解析する。
    #
    #@author NICT
    #
    class MetaMethod < BaseMethod
        # メソッド名
        METHOD_NAME = "meta"

        # 空の場合の中間コード出力
        HASH_EMPTY = {}

        #@return [Hash] 空の場合の中間コード出力
        attr_reader :hash_empty

        #@param [Hash] metas メタ情報のハッシュ
        #
        def initialize(metas)
            @metas = metas
            @hash_empty = HASH_EMPTY
        end

        #metaメソッドに対応した文字列か判定する。
        def self.match?(text)
            return BaseMethod::match?(text,METHOD_NAME)
        end

        # metaメソッド構文を解析する。
        #
        #@param [DSNText] text メソッドの文字列
        #@return [Array<String>] メソッドの引数の配列
        #@raise [DSNFormatError] metaメソッドの引数にフォーマットが正しくない値が設定された。
        #
        def self.parse(text)
            # フォーマットの定義
            format = nil
            args = BaseMethod.parse(text, METHOD_NAME, format)

            metas = Hash.new()
            args.each do |arg|
                reg = REG_META_ARG.match(arg.single_line)
                if not reg.nil?()
                    metas[reg[1]] = reg[2]
                else
                    raise DSNFormatError.new(ErrorMessage::ERR_TRANSMISSION_METHOD, text)
                end
            end

            return MetaMethod.new(metas)
        end

        #中間コードに変換する
        def to_hash()

            result = @metas.nil?() ? @hash_empty : @metas
            return result
        end
    end
end
