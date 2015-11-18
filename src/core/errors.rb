# -*- coding: utf-8 -*-
require 'timeout'

# タイムアウト時間
DEFAULT_TIMEOUT = 60
# NCPSサーバーとの接続時のタイムアウト時間
TIMEOUT_TO_SERVER = DEFAULT_TIMEOUT
# 他のNCPSクライアントとの接続時のタイムアウト時間
TIMEOUT_TO_CLIENT = DEFAULT_TIMEOUT
# PAIXサーバーとの接続時のタイムアウト時間
TIMEOUT_TO_PAIX = DEFAULT_TIMEOUT

#= ネットワークエラー
# ネットワークの構成に問題がある場合に送出されるエラー
#
#@author NICT
#
class NetworkError < StandardError; end

#= 無効なIDエラー
# サーバーへ要求したIDが不正だった場合に送出されるエラー
#
#@author NICT
#
class InvalidIDError < StandardError; end

#= サーバー内部エラー
# サーバー内で予期せぬエラーが発生した場合に送出されるエラー
#
#@author NICT
#
class InternalServerError < StandardError; end

#= アプリケーションエラー
# アプリケーション内でエラーが発生した場合に送出されるエラー
#
#@author NICT
#
class ApplicationError < StandardError; end

