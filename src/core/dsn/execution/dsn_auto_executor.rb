# -*- coding: utf-8 -*-
require 'logger'
require 'singleton'

require_relative '../../utils'
require_relative '../../app_if'

#= DSN記述自動実行処理クラス
# create_dsn API で生成されたDSN記述を所定のディレクトリから取得し、
# create_overlay API を使用してチャネルを生成する。
#
#@author NICT
#
class DSNAutoExecutor
    include Singleton

    #@return [Hash]         自動実行中DSN記述
    attr_reader   :running_dsn

    def initialize()
        log_trace()

        @running_dsn = {}
    end

    # 初期設定
    #
    #@param [Integer] interval DsnAutoExecutorの動作周期
    #
    def setup(interval)
        @dsn_store_path     = $config[:dsn_store_path]
        @dsn_file_ext       = $config[:dsn_file_ext]
        @dsn_log_store_path = $config[:dsn_log_store_path]
        @dsn_log_file_ext   = $config[:dsn_log_file_ext]

        start(interval)
    end

    #@return [Hash] DSN記述(key:オーバーレイ名)
    #
    def gather_dsn_files()
        dsn_requests = {}
        dsn_files = Dir.glob(@dsn_store_path + "/*" + @dsn_file_ext)

        dsn_files.each do |dsn_file|
            File.open(dsn_file, "r") do |rfile|
                if rfile.flock(File::LOCK_EX|File::LOCK_NB)
                    overlay_name = File.basename(dsn_file, @dsn_file_ext)
                    dsn_requests[overlay_name] = rfile.read
                else
                    next # 別プロセスロック(書き込み)中は待たずに次へ。
                end
            end # File.close時にロック解除される。
        end
        return dsn_requests
    end

    #@param [String] オーバーレイ名(＝ファイル名)
    #@param [String] dsn_desc DSN記述
    #@return [String] DSN記述ファイル格納パス
    #@note 拡張子は自動で付与する。
    #
    def store_dsn_file(overlay_name, dsn_desc)
        dsn_file = @dsn_store_path + '/' + overlay_name + @dsn_file_ext

        File.open(dsn_file, "w") do |wfile|
            wfile.flock(File::LOCK_EX)
            # 別プロセスロック(読み出し)中はここで待つ。
            wfile.write(dsn_desc)
        end # File.close時にロック解除される。

        return dsn_file
    end

    #@param [String] オーバーレイID
    #@param [String] メッセージ
    #
    def log_auto_execute_message(overlay_id, message)
        overlay = @running_dsn.select {|key, val| val["id"] == overlay_id } # 1件だけ取れる
        overlay_name = overlay.keys[0]
        log_file = @dsn_log_store_path + '/' + overlay_name + @dsn_log_file_ext

        File.open(log_file, "a") do |wfile|
            wfile.puts(message)
        end
    end

    private

    # 周期実行用スレッドを開始する。
    #
    #@param [Integer] interval DsnAutoExecutorの動作周期
    #
    def start(interval)
        Thread.new do
            loop do
                begin
                    log_trace()
                    update_overlays_from_dsn_files()
                rescue
                    log_error("", $!)
                end

                sleep interval
            end
        end
    end

    # 周期実行処理
    #
    def update_overlays_from_dsn_files()
        log_time()

        requests_dsn = gather_dsn_files()
        requests_names = requests_dsn.keys
        running_names = @running_dsn.keys

        # 作成
        (requests_names - running_names).each do |overlay_name|
            dsn_desc = requests_dsn[overlay_name]
            create_overlay(overlay_name, dsn_desc)
        end

        # 削除
        (running_names - requests_names).each do |overlay_name|
            delete_overlay(overlay_name)
        end

        # 変更
        (requests_names & running_names).each do |overlay_name|
            dsn_desc = requests_dsn[overlay_name]
            if dsn_desc == @running_dsn[overlay_name]["dsn"]
                # 変更なし
            else
                # オーバーレイを変更する
                modify_overlay(overlay_name, dsn_desc)
            end
        end

        log_time()
    end

    #@param [String] overlay_name オーバーレイ名(＝DSNファイル名)
    #@param [String] dsn_desc DSN記述
    #
    def create_overlay(overlay_name, dsn_desc)
        overlay_id = ApplicationRPCServer.create_overlay(overlay_name, dsn_desc, nil)
        @running_dsn[overlay_name] = { "id" => overlay_id, "dsn" => dsn_desc }
    end

    #@param [String] overlay_name オーバーレイ名(＝DSNファイル名)
    #
    def delete_overlay(overlay_name)
        ApplicationRPCServer.delete_overlay(@running_dsn[overlay_name]["id"])
        @running_dsn.delete(overlay_name)
    end

    #@param [String] overlay_name オーバーレイ名(＝DSNファイル名)
    #@param [String] dsn_desc DSN記述
    #
    def modify_overlay(overlay_name, dsn_desc)
        ApplicationRPCServer.modify_overlay(overlay_name, @running_dsn[overlay_name]["id"], dsn_desc)
        @running_dsn[overlay_name]["dsn"] = dsn_desc
    end

    # インスタンスメソッドをクラスに委譲
    class << self
        extend Forwardable
        def_delegators :instance, *DSNAutoExecutor.instance_methods(false)
    end
end

