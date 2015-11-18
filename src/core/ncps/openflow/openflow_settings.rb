require 'json'

# 名前解決によるパフォーマンス低下の防止
TCPSocket.do_not_reverse_lookup = true

#= 共通データ設定
#@author NICT
#
module OpenflowSettings
    # OFC向けのゲートウェイ向けポート番号
    BROAD_CAST_PORT = 55555
    # TCP/IP通信時のセパレータ文字列
    SEPARTOR = '\r\n\r\n'
    # OFCからのPush通知キー
    PUSH_KEY = 'PUSH_REQUEST'
    # TOSの最大値
    TOS_SIZE = 64

    # ポート番号をTOSに変換する。
    #
    #@param [Integer] port ポート番号
    #@return [Integer] TOSを使用するポート番号の時、true
    #
    def to_tos(port)
        return ((port - $config[:data_port_base]) % TOS_SIZE) * 4
    end
end

#= ピア(ノード)クラス
#@author NICT
#
class Peer
    @@TCP = 'TCP'
    @@UDP = 'UDP'

    #@return [String]  IPアドレス
    attr_accessor :ipaddr
    #@return [Integer] ポート番号
    attr_accessor :port
    #@return [String]  通信プロトコル（TCP｜UDP）
    attr_accessor :protocol
    #@return [String]  ドメイン名
    attr_accessor :domain

    #@param [String] ipaddr IPアドレス
    #@param [Integer] port ポート番号
    #@param [String] protocol 通信プロトコル（TCP｜UDP）
    #@param [String] domain ドメイン名
    #
    def initialize(ipaddr, port, protocol = @@TCP, domain = nil)
        @ipaddr = ipaddr
        @port = port
        @protocol = protocol
        @domain = domain
    end

    # JSONからインスタンスを生成する
    #
    #@param [String] json_str インスタンス作成用文字列
    #@return [Peer] 生成したインスタンス
    #
    def self.from_json(json_str)
        self.from_hash(JSON.parse(json_str))
    end

    # Hashからインスタンスを生成する
    #
    #@param [Hash] hash インスタンス作成用ハッシュ
    #@return [Peer] 生成したインスタンス
    #
    def self.from_hash(hash)
        self.new(hash["ipaddr"], hash["port"], hash["protocol"], hash["domain"])
    end

    #@return [String] 文字列表現
    def to_s
        '' + @protocol.to_s + ":" + @ipaddr.to_s + ":" + @port.to_s + ":" + @domain.to_s
    end
end
