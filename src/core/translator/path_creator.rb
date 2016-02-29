# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative '../utils'
require_relative './path'

#= パス生成クラス
# パスの生成クラスは以下のインターフェースを提供する。
#  - パス生成
#  - パス更新
#
#@author NICT
#
class PathCreator

    #@param [String] channel_id チャネルID
    #
    def initialize(channel_id)
        @channel_id = channel_id
        @path_count = 0
    end

    #@param [ChennelRequest] channel_req チャネル要求
    #@return [Arrya<Path>] チャネル要求に基づくパスのリスト
    #
    def create(channel_req)
        raise NotImplementedError
    end

    #@param [Arrya<Path>] paths 前回生成したパスのリスト
    #@param [ChennelRequest] channel_req チャネル要求
    #@return [Arrya<Path>] チャネル要求に基づくパスのリスト
    #
    def update(paths, channel_req)
        raise NotImplementedError
    end

    private

    # #{ミドルウェアID}_#{オーバーレイID}_#{チャネルID}_#{パスID}
    #
    def generate_path_id()
        @path_count += 1
        path_id = @channel_id + '_' + @path_count.to_s
        return path_id
    end
end

#= パス生成クラスの実装サンプル
# 中間ノードを経由しないシンプルなパスを作成する。
#
#@author NICT
#
class SimplePathCreator < PathCreator

    #@see PathCreator#create
    def create(services, channel_req)
        log_trace(services, channel_req)
        processings = channel_req["app_req"]["processing"]
        service_pairs = create_pairs(services, channel_req)    # 無造作に送受信サービスを選ぶ

        paths = []
        service_pairs.each do |src_service, dst_service|
            path = create_path(src_service, dst_service, processings)
            paths << path
            log_debug{"channel id: #{@channel_id}, new path: #{path}"}
        end
        return paths
    end

    #@see PathCreator#update
    def update(paths, services, channel_req)
        log_trace(paths, services, channel_req)
        processings   = channel_req["app_req"]["processing"]
        service_pairs = create_pairs(services, channel_req)

        update_paths = []
        delete_paths = []
        # 同じペアは再利用する
        paths.each do |path|
            index = service_pairs.index{ |src_service, dst_service| path.same_path?(src_service, dst_service) }
            if index.nil?
                # データ転送の切れ目を作らないために、すぐには削除しない
                delete_paths << path
            else
                # 生成済みのパスは中間処理のみを最適化
                optimiazed = optimiaze_processings(path.src_service, path.dst_service, processings)
                path.update(optimiazed)
                update_paths << path
                log_debug{"channel id: #{@channel_id}, update path: #{path}"}

                service_pairs.delete_at(index)
            end
        end

        # 不足分を生成
        service_pairs.each do |src_service, dst_service|
            path = create_path(src_service, dst_service, processings)
            update_paths << path
            log_debug{"channel id: #{@channel_id}, new path: #{path}"}
        end

        delete_paths.each do |path|
            path.delete()
            log_debug{"channel id: #{@channel_id}, delete path: #{path}"}
        end

        return update_paths
    end

    private

    # チャネル要求の並列数を満たすように送信元と送信先のサービスのペアを作成する。
    #
    def create_pairs(services, channel_req)
        log_trace(services, channel_req)
        src = channel_req["scratch"]
        dst = channel_req["channel"]
        srcs = services[src["name"]]["services"]
        dsts = services[dst["name"]]["services"]

        # サービス数がmultiを満たさない場合はリンク不足とする
        src_multi = src["multi"] | 1
        dst_multi = dst["multi"] | 1
        lack = [srcs.size.to_f / src_multi, dsts.size.to_f / dst_multi, 1.0].min
        # リンク数を不足分に合わせる
        src_size  = (src_multi * lack).ceil
        dst_size  = (dst_multi * lack).ceil
        path_size = [src_size, dst_size].max
        pairs = []
        for index in 0 .. path_size - 1 do
            # 送信元または送信先が少ない場合は、不足側を多重に使う。
            # （multiの指定を超える過度な多重化はしない）
            pairs << [srcs[index % src_size], dsts[index % dst_size]]
        end
        return pairs
    end

    # パスを生成する。
    #
    def create_path(src_service, dst_service, processings)
        log_trace(src_service, dst_service, processings)
        path_id = generate_path_id()
        optimiazed = optimiaze_processings(src_service, dst_service, processings)
        path = Path.new(path_id, src_service, dst_service, optimiazed)
        path.create()
        return path
    end

    # 送信元ノードで一括処理を行う
    #
    def optimiaze_processings(src_service, dst_service, processings)
        return [[src_service.ip, processings]]
    end

end
