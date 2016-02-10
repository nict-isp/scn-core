#-*- codIng: utf-8 -*-
require_relative '../../utils'
require_relative '../../utility/m2m_format'
require_relative '../compile/communication_data'

#= データ送信受信時の中間処理クラス
# データに対する抽出処理を実施する
#
#@author NICT
#
class OnNodeProcessing

    #@param [String] overlay_id オーバーレイID
    #@param [Service] service 中間処理を行なうサービスの情報
    #@param [Hash] request アプリケーション要求
    #
    def initialize(service, request)
        @service = service
        @request = nil

        update_request(request)
    end

    # アプリケーション要求に基づき中間処理を再生成する。
    #
    #@param [Hash] request アプリケーション要求
    #@return [void]
    #
    def update_request(request)
        if not(request.kind_of?(Array))
            @selects = {}

        elsif request != @request
            service_info = @service.info["data"] || {}
            @selects = request.inject({}) { |hash, select|
                hash[select["name"]] = DSN::CommunicationData.from_hash(select, service_info)
                hash
            }
        end
        log_debug() {@selects}

        @request = request
    rescue
        log_error("", $!)
    end

    # 情報抽出を実行する。（破壊的な操作）
    #
    # データ名を指定されなかった情報を削除する。
    # データ名の指定が一つもなかった場合は何もしない。
    #
    # M2Mデータの場合は、メタ情報のスキーマも合わせて変更する。
    # M2Mデータの場合は、必須情報（緯度経度高度時間）は削除しない。
    #
    #@param [Hash] data 情報抽出対象のデータ
    #@return [Hash] 情報抽出後のデータ
    #
    def execute(data)
        extracts = @selects.keys()
        if extracts.size > 0
            if M2MFormat.formatted?(data)
                data = M2MFormat.convert_current_format(data)
                extracts |= ["latitude", "longitude", "altitude", "time"]
                M2MFormat.extract_schema(data, extracts)
                extracted = M2MFormat.get_values(data).map { |value|
                    extracts.inject({}){ |hash, key| hash[key] = value[key]; hash }
                }
                M2MFormat.set_values(data, extracted)
            else
                data = data.map { |value|
                    extracts.inject({}){ |hash, key| hash[key] = value[key]; hash }
                }
            end
        end
        return data
    end
end

