# -*- coding: utf-8 -*-
require 'sync'

#= 同期ハッシュ
# キーへの読み書きを同期するハッシュクラス
# 同期の必要なメソッドをオーバーライドする
#
# - :SH 共有ロック
# - :EX 排他ロック
#
#@author NICT
#
class SyncHash < Hash
    include Sync_m

    #@see Hash#[]
    def [](key)
        sync_synchronize(:SH) { super }
    end

    #@see Hash#[]=
    def []=(key, value)
        sync_synchronize(:EX) { super }
    end

    #@see Hash#delete(key)
    def delete(key)
        sync_synchronize(:EX) { super }
    end

    #@see Hash#each_value
    def each_value()
        sync_synchronize(:SH) { super }
    end

    #@see Hash#each
    def each()
        sync_synchronize(:SH) { super }
    end

    #@see Hash#values
    def values()
        sync_synchronize(:SH) { super }
    end

    #@see Hash#select
    def select()
        sync_synchronize(:SH) { super }
    end

    # SyncHashインスタンスを生成する。
    #
    #@param value [Object] SyncHashへ変換する値
    #@return [SyncHash] 変換したSyncHash
    #
    def self.[](value)
        hash = SyncHash.new()
        hash.update(Hash[value])
        return hash
    end
end
