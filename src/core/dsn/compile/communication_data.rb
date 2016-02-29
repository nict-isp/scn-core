# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative '../../utils'

module DSN

    #= Communicationオプションデータクラス
    # DSN記述のscratch,channelで設定するオプションを設定するクラス
    #
    #@author NICT
    #
    class CommunicationData

        #@return [String] データ名
        attr_reader :name
        #@return [DataPath] データパス
        attr_reader :path
        #@return [String] デフォルト値
        attr_reader :value

        #@param [String] value デフォルトデータ値
        #@param [DataPath] path データパス
        #@param [DataPath] service サービスのデフォルトパス
        #@param [String] name データ名
        #
        def initialize(value=nil, path=nil,service=nil,name=nil)
            @value = value
            @path = path
            @service_path = service
            @name = name
        end

        # クラス内のデータを取得する
        #
        #@return [Object] データ
        #
        def get_data(hash)
            if  not(@value.nil?)
                value = @value

            elsif not(@path.nil?)
                value =  @path.find(hash)

            elsif not(@service_path.nil?)
                value =  @service_path.find(hash)

            elsif not(@name.nil?)
                value = hash[@name]
            else
                value = nil
            end
            return value
        end

        # 文字列表現のオプションデータを解析し、インスタンス化する
        #
        #@param [String] text 文字列表現のオプションデータ
        #@example
        # データ名のみ:     data_name
        # デフォルト値設定: data_name = data_value
        # パス設定あり:     data_name : data_path
        #@return [CommunicationData] コミュニケーションデータのインスタンス
        #
        def self.parse(text)
            name = nil
            path = nil
            value = nil
            # text = dsn_text.single_line
            if text =~ /(\w+)\s*=\s*(\w+)/
                #$1:データ名,$2:データ値
                #data_name = data_value形式の場合
                name = $1
                value = $2
            elsif text =~ /(\w+)\s*:\s*([\w\/]+)/
                #$1:データ名,$2:データパス
                #data_name : data_value形式の場合
                name = $1
                path = $2
            else
                #上記以外の場合は、data_nameのみ
                name = text
            end
            return CommunicationData.new(value, path, nil, name)

        end

        # データパス（文字列）からインスタンスを生成する
        #
        #@param [String] path データパス
        #@return [CommunicationData] コミュニケーションデータのインスタンス
        #
        def self.from_data_path(path)
            data_path = DataPath.parse(path)
            return CommunicationData.new(nil, data_path)
        end

        # 中間コードからインスタンスを生成する
        #
        #@param [Hash] hash 中間コード
        #@param [Hash<String, String>] info サービスのデータパス情報
        #@param [Array<String>] info サービスのデータ名の配列
        #@return [CommunicationData] コミュニケーションデータのインスタンス
        #
        def self.from_hash(hash, info = nil)
            name         = hash[KEY_SELECT_NAME]
            value        = hash[KEY_SELECT_VALUE]
            path         = DataPath.parse(hash[KEY_SELECT_PATH])
            if info.kind_of?(Hash) && info.has_key?(name)
                default_path = DataPath.parse(info[name])
            else
                default_path = nil
            end
            return CommunicationData.new(value, path, default_path, name)
        end

        #コミュニケーションデータを中間コードに変換する。
        #
        def to_hash
            hash = {KEY_SELECT_NAME => @name}
            unless @value.nil?
                hash[KEY_SELECT_VALUE] = @value
            end
            unless @path.nil?
                hash[KEY_SELECT_PATH] = @path
            end
            return hash
        end

    end

    #= データパス解析クラス
    # オプション指定するデータパスを解析するクラス
    #
    #@author NICT
    #
    class DataPath

        # コンストラクタ
        #
        #@param [Array] 配列に分解されたデータパス
        #
        def initialize(segments)
            @segments = segments
        end

        #@return [Regex] キー名の正規表現
        NORMAL_KEY_REGEXP = /[a-zA-Z_-]+/
        #@return [Regex] 配列要素の正規表現
        ARRAY_KEY_REGEXP = /^([a-zA-Z_-]+)\[(\d+)\]/

        # 文字列表現のデータパスを解析し、インスタンス化する
        #
        #@param [String] path 文字列表現のデータパス
        #@return [DataPath] データパスのインスタンス
        #
        def self.parse(path)
            return nil if path.nil?

            segments =  path.sub(/^\//,'').split('/')
            # 配列要素のキー名と添え字を2つの要素に分解
            segments = segments.collect{ |segment|
                if ARRAY_KEY_REGEXP =~ segment
                    [$1, $2.to_i]
                elsif NORMAL_KEY_REGEXP =~ segment
                    segment
                else
                    raise "format error"
                end
            }.flatten
            DataPath.new(segments)
        end

        # データからデータパスの要素を取り出す
        #
        #@param [Hash] hash データ
        #@return [Object] 取り出した要素
        #
        def find(hash)
            # データ階層の探査
            return @segments.inject(hash) { |hash, segment| hash[segment] }
        end

        # ハッシュ表現の要素を返す。
        #
        #@return [Hash] ハッシュ表現の要素
        #
        def to_hash()
            return @segments
        end

        #@see Object#to_s()
        def to_s()
            return "/" << @segments.join("/")
        end
    end
end
