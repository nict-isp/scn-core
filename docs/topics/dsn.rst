============
DSN記述言語
============

DSNの基本構造
==============

DSNは、 ``state do`` ブロックと ``bloom do`` ブロックにより構成されます。

::

    state do
      ...
    end

    bloom do
      ...
    end


state doブロック
=================

``state do`` ブロックでは、サービスを定義します。


**@service_name**

``discovery`` で指定した条件にマッチするサービスを検索し、 ``@service_name`` でサービス名を定義します。

::

    @service_name: discovery(attr_name=attr_value, attr_name=attr_value, ...)

*  ``attr_name`` : (文字列) 検索対象の任意の属性名
*  ``attr_value`` : (文字列) 検索対象の任意の属性値


``attr_name=attr_value`` を複数記述した場合は、AND条件として扱います。
条件を満たすサービスが複数ある場合は、そのサービスが稼働しているノードの資源に最も余裕のあるものが選択されます。

以下の例では、 ``category`` 属性の値が ``sensor`` 、かつ ``type`` 属性の値が ``twitter`` であるサービスを ``@twitter`` と定義します。

::

    @twitter: discovery(category=sensor, type=twitter)


**scratch**

``scratch`` は、 ``@service_name`` をデータ送信サービスとしてスクラッチ名を定義します。

::

    scratch: scratch_name, @service_name

*  ``scratch_name`` : (文字列) 任意のスクラッチ名
*  ``@service_name`` : (文字列) 定義されたサービス名


以下の例では、 ``@twitter`` サービスをデータ送信サービスとして ``s_twitter`` と定義します。

::

    scratch: s_twitter, @twitter


**channel**

``channel`` は、 ``@service_name`` をデータ受信サービスとしてチャネル名を定義します。

::

    channel: channel_name, @service_name

*  ``channel_name`` : (文字列) 任意のチャネル名
*  ``@service_name`` : (文字列) 定義されたサービス名

* 
以下の例では、 ``@store`` サービスをデータ受信サービスとして ``c_store`` と定義します。

::

    channel: c_store, @store



bloom doブロック
=================

``bloom do`` ブロックでは、データフローおよびイベントを定義します。


データフロー
-------------

データフローは ``<~`` で定義します。
``scratch_name`` が送信したデータを、 ``channel_name`` で受信する場合、以下のように記述します。

::

    channel_name <~ scratch_name

*  ``channel_name`` : (文字列) 定義されたチャネル名
*  ``scratch_name`` : (文字列) 定義されたスクラッチ名



In-Networking Data Processing
------------------------------

.. _M2Mデータフォーマット: https://github.com/nict-isp/uds-sdk/blob/master/docs/refs/m2m/v102.rst

データフローに対し、In-Networking Data Processingを指定することができます。
SCNミドルウェアで送受信するデータは `M2Mデータフォーマット`_ であるため、
DSN記述は、 `M2Mデータフォーマット`_ を扱うことを前提とした定義になっています。


**フィルタリング**

データのフィルタリングは ``filter()`` で定義します。
``scratch_name`` から送信したデータのうち、指定した条件を満たすデータのみを  ``channel_name`` へ送信します。

::

    channel_name <~ scratch_name.filter(filter_conditions)


``filter_conditions`` の指定には、以下を使用します。


.. _conditions:

=======================================  ==============================================================================================================
項目                                     内容
=======================================  ==============================================================================================================
算術比較                                 ``>`` 、 ``>=`` 、 ``==`` 、 ``!=`` 、 ``<=`` 、 ``<``
like(data_name, regex)                   ``data_name`` の値（文字列のみ指定可能）と、 ``regex`` (Ruby準拠)とのパターンマッチングを行ないます。
range(data_name, min_value, max_value)   ``min_value <= data_name`` の算術比較と、 ``data_name < max_value`` の算術比較がどちらも真の時、真を返します。
not                                      ``like()`` と ``range()`` の頭に付与することで、条件の否定を表します。算術比較には使用できません。
=======================================  ==============================================================================================================


条件を ``&&`` や ``||`` で繋ぐことで、複合条件を記述できます。
また、条件を ``( )`` で括ることで、優先順位をつけることができます。


以下の例では、 ``s_panda`` の送信データに含まれる ``avg_rainfall`` の値が ``25`` 以上、かつ
``latitude`` の値が ``134.0`` 以上 ``136.0`` 未満のデータのみを ``c_store`` へ送信します。

::

    c_store <~ s_panda.filter(avg_rainfall >= 25 && range(latitude, 134.0, 136.0))


以下の例では、 ``s_twitter`` の送信データに含まれる ``tweet`` の値に、 ``豪雨`` または
``暴風`` の文字列が含まれるデータのみを ``c_store`` へ送信します。

::

    c_store <~ s_twitter.filter(like(tweet, ".*豪雨*.") || like(tweet, ".*暴風*."))


**時間による間引き**

時間によるデータの間引きは、 ``cull_time()`` で定義します。
``scratch_name`` から送信したデータについて、指定した時間条件でデータを間引き、 ``channel_name`` へ送信します。

::

    channel_name <~ scratch_name.cull_time(numerator, denominator, time(time, start_time, end_time, time_interval, time_unit))

*  ``numerator`` : (整数) 間引き率の分子
*  ``denominator`` : (整数) 間引き率の分母
*  ``start_time`` : (yyyy/mm/ddThh:mm:ss) 間引き対象のデータの開始時刻
*  ``end_time`` : (yyyy/mm/ddThh:mm:ss) 間引き対象のデータの終了時刻
*  ``time_interval`` : (整数) 間引き対象の時間間隔
*  ``time_uni`` : (day|hour|minute|second) time_intervalの単位


以下の例では、 ``s_panda`` の送信データに含まれる ``time`` の値を間引き対象とし、
``2015/01/01/T00:00:00`` から ``2015/03/31T23:59:59`` の範囲において、
``30 second`` 間隔で ``10`` 分の ``1`` に間引いたデータを ``c_store`` へ送信します。

::

    c_store <~ s_panda.cull_time(1, 10, time(time, "2015/01/01T00:00:00", "2015/03/31T23:59:59", 30, "second"))



**空間による間引き**

空間によるデータの間引きは、 ``cull_space()`` で定義します。
``scratch_name`` から送信したデータについて、指定した空間条件でデータを間引き、 ``channel_name`` へ送信します。

::

    channel_name <~ scratch_name.cull_space(numerator, denominator, space(latitude, longitude, west, south, east, north, lat_interval, long_interval))

*  ``numerator`` : (整数) 間引き率の分子
*  ``denominator`` : (整数) 間引き率の分母
*  ``west`` : (小数) 間引き空間の最西の経度
*  ``sourh`` : (小数) 間引き空間の最南の緯度
*  ``east`` : (小数) 間引き空間の最東の経度
*  ``north`` : (小数) 間引き空間の最北の緯度
*  ``lat_interval`` : (整数) 間引き対象の緯度間隔
*  ``long_interval`` : (整数) 間引き対象経度間隔


以下の例では、 ``s_panda`` の送信データに含まれる ``latitude`` と ``longitude`` の値を間引き対象とし、
緯度 ``20.0`` から ``45.0`` 、経度 ``122.0`` から ``153.0`` の範囲において、
緯度を ``0.1`` 度、経度を ``0.3`` 度間隔で ``10`` 分の ``1`` に間引いたデータを ``c_store`` へ送信します。

::

    c_store <~ s_panda.cull_space(1, 10, space(latitude, longitude, 122.0, 20.0, 153.0, 45.0, 0.1, 0.3)



**時空間による集約**

データの集約は、 ``aggregate()`` で定義します。
``scratch_name`` から送信したデータを時空間でグループ化し、集約した以下のデータを、 ``channel_name`` へ送信します。


====== =====================================
項目   内容
====== =====================================
max    グループ化された範囲のデータの最大値
min    グループ化された範囲のデータの最小値
avg    グループ化された範囲のデータの平均値
sum    グループ化された範囲のデータの合計値
count  グループ化された範囲のデータ数
====== =====================================


::

    channel_name <~ scratch_name.aggregate(data_name, time(time, start_time, end_time, time_interval, time_unit), space(latitude, longitude, west, south, east, north, lat_interval, long_interval)

*  ``data_name`` : (文字列) ``scratch_name`` から送信されたデータに含まれるデータ名
*  ``start_time`` : (yyyy/mm/ddThh:mm:ss) 集約の開始時刻
*  ``end_time`` : (yyyy/mm/ddThh:mm:ss) 集約の終了時刻
*  ``time_interval`` : (整数) 集約する時間間隔
*  ``time_uni`` : (day|hour|minute|second) time_intervalの単位
*  ``west`` : (小数) 集約空間の最西の経度
*  ``sourh`` : (小数) 集約空間の最南の緯度
*  ``east`` : (小数) 集約空間の最東の経度
*  ``north`` : (小数) 集約空間の最北の緯度
*  ``lat_interval`` : (整数) 集約する緯度間隔
*  ``long_interval`` : (整数) 集約する経度間隔


以下の例では、 ``s_panda`` の送信データに含まれる ``avg_rainfall`` の値を、
``2015/01/01/T00:00:00`` から ``2015/03/31T23:59:59`` の範囲において、
``30 second`` 間隔で ``10`` 分の ``1`` に集約し、
緯度 ``20.0`` から ``45.0`` 、経度 ``122.0`` から ``153.0`` の範囲において、
緯度を ``0.1`` 度、経度を ``0.3`` 度の間隔で集約したデータを ``c_store`` へ送信します。

::

    c_store <~ s_panda.aggregate(avg_rainfall, time(time, "2015/01/01T00:00:00", "2015/03/20T23:59:59", 30, "second"), space(latitude, longitude, 122.0, 20.0, 153.0, 45.0, 0.1, 0.3))


集約後のデータは、以下の形式になります。

::

   [
      {
         "info" => {
             "name" => "avg_rainfall",
             "west" => 122.0, "east" => 153.0,
             "south" => 20.0, "north" => 45.0,
             
             "start" => "2015/01/01T00:00:00",
             "end"   => "2015/03/20T23:59:59",
         },
         "summary" => {
             "max"   => 30.0,
             "min"   => 5.0,
             "avg"   => 10.0,
             "sum"   => 1000.0,
             "count" => 100
         }
      }
   ]


**QoS**

データのQoSは、 ``qos()`` で定義します。
``scratch_name`` のデータを指定されたQoSで ``channel_name`` へ送信します。
ただし、ここで指定したQoSの数値を必ず保障するというものではありません。

::

    channel_name <~ scratch_name.qos(qos_value)

*  ``qos_value`` : (整数) 要求するQoSの値(単位：bps)


以下の例では、 ``s_panda`` の送信レートが少なくとも ``1Mbps`` になるよう、 ``c_store`` へ送信します。

::

    c_store <~ s_panda.qos(1024000)


**メタ情報の付与**

メタ情報として、データを格納するテーブル名を、 ``meta()`` で定義することができます。
``Table=table_name`` と定義することで、 ``scratch_name`` の送信データを ``channel_name``
を通して ``table_name`` で指定したテーブル名に格納します。
この時、 ``channel_name`` で指定するチャネルには、データストア用のサービスを指定する必要があります。

::

    channel_name <~ scratch_name.meta(Table=table_name)

*  ``table_name`` : (文字列) 任意のテーブル名

以下の例では、 ``s_panda`` の送信データが ``c_store`` を介して ``PANDA_SENSORE`` テーブルへ格納されます。

::

    c_store <~ s_panda.meta(Table=PANDA_SENSOR)


イベント
=========

トリガー
---------

イベントのトリガーは、以下で定義します。

*  ``<+`` (イベント立ち上げ)
*  ``<-`` (イベント立ち下げ)
*  ``<+-`` (イベント立ち上げ/立ち下げ)

``channel_name`` が、 ``trigger_interval`` 内に受信した ``conditions`` の条件を満たすデータ数が
``trigger_condtions`` を満たした時、
``<+`` では ``event_name`` を ``on`` 、 ``<-`` では ``off`` 、 ``<+-`` では ``on`` または ``off`` にします。

::

    event_name <+ channel_name.trigger(trigger_interval, trigger_condtions, condiions)

*  ``event_name`` : (文字列) 任意のイベント名
*  ``trigger_interval`` : (整数) イベント立ち上げ/立ち下げ条件の周期
*  ``trigger_conditions`` :  :ref:`conditions<conditions>` で指定可能な条件
*  ``conditions`` :  :ref:`conditions<conditions>` で指定可能な条件


イベントブロック
-----------------

イベントブロックは、 ``bloom do`` ブロック内に記述します。

``event_name.on do`` ブロックは ``event_name`` が ``on`` の場合に有効になり、
``event_name.off do`` ブロックは、 ``event_name`` が ``off`` の場合に有効となる。

::

    bloom do
        event_name.on do
          ...
        end

        event_name.off do
          ...
        end
    end


*  ``event_name`` : (文字列) 任意のイベント名


以下の例では、 ``c_store`` が ``30`` 秒間に ``130`` 個以上データを受信した際に、 ``heavy_rain`` イベントが発火し、
``s_twitter`` と ``s_traffic`` のデータを収集します。

::

    bloom do
        c_store <~ s_panda.filter(avg_rainfall >= 25)
        heavy_rain <+ c_store.trigger(30, count > 130, avg_rainfall > 30)

        heavy_rain.on do
            c_store <~ s_twitter
            c_store <~ s_traffic
        end
    end



特別な記述方法
===============

複数のIn-Network Data Processingの実行定義
-------------------------------------------

1つのデータフローで複数のIn-Network Data Processingを定義する際は、以下のようにProcessingの定義を ``.`` で連結します。

::

    channel_name <~ scratch_name.filter(xxx).cull_time(xxx)

以下の例では、はじめにフィルタリングが実施され、その後時間による間引きが実施されます。

::

    c_store <~ s_panda.filter(avg_rainfall >= 25).cull_time(1, 10, time(time, "2015/01/01T00:00:00", "2015/03/31T23:59:59", 30, "second"))



複数の@serviceの定義
---------------------

通常、 ``@service_name`` では、 条件にマッチした1つのサービスが定義されますが、 ``discovery`` の条件に
``multi=multi_num`` を指定することで、条件にマッチした複数のサービスを定義することができます。

以下の例では、 ``multi=3`` の定義により、検索にマッチした3つのサービスが ``@store`` に定義されます。
そして、 ``bloom do`` ブロックで ``c_store <~ s_twitter`` と定義するだけで、1対3のデータフローが定義されます。

::

    state do
        @twitter: discovery(category=sensor, type=twitter)
        @store: discovery(categry=application, type=store, multi=3)
        scratch: s_twitter, @twitter
        channel: c_store, @store
    end

    bloom do
        c_store <~ s_twitter
    end

                 +---> c_store
                 |
    s_twitter ---+---> c_store
                 |
                 +---> c_store


送信元サービス、送信先サービスの ``multi`` の値の組み合わせによるデータフローのパターンを示します。

::

    [1対1]
        @scratch: discovery(aaa=bbb, multi=1)
        @channel: discovery(xxx=yyy, multi=1)

            s_scratch -------> c_channel

    [1対多]
        @scratch: discovery(aaa=bbb, multi=1)
        @channel: discovery(xxx=yyy, multi=3)

                         +---> c_channel
                         |
            s_scratch ---+---> c_channel
                         |
                         +---> c_channel

    [多対1]
        @scratch: discovery(aaa=bbb, multi=3)
        @channel: discovery(xxx=yyy, multi=1)

            s_scratch ---+
                         |
            s_scratch ---+---> c_channel
                         |
            s_scratch ---+

    [多対多(送信サービス数 = 受信サービス数)]
        @scratch: discovery(aaa=bbb, multi=3)
        @channel: discovery(xxx=yyy, multi=3)

            s_scratch -------> c_channel
            s_scratch -------> c_channel
            s_scratch -------> c_channel

    [多対多(送信サービス数 < 受信サービス数)]
        @scratch: discovery(aaa=bbb, multi=2)
        @channel: discovery(xxx=yyy, multi=4)

            s_scratch ---+---> c_channel
                         |
                         +---> c_channel
            s_scratch ---+---> c_channel
                         |
                         +---> c_channel

    [多対多(送信サービス数 < 受信サービス数)]
        @scratch: discovery(aaa=bbb, multi=3)
        @channel: discovery(xxx=yyy, multi=4)

            s_scratch -------> c_channel
            s_scratch -------> c_channel
            s_scratch ---+---> c_channel
                         |
                         +---> c_channel

    [多対多(送信サービス数 > 受信サービス数)]
        @scratch: discovery(aaa=bbb, multi=4)
        @channel: discovery(xxx=yyy, multi=2)

            s_scratch ---+---> c_channel
                         |
            s_scratch ---+
            s_scratch ---+---> c_channel
                         |
            s_scratch ---+

    [多対多(送信サービス数 > 受信サービス数)]
        @scratch: discovery(aaa=bbb, multi=4)
        @channel: discovery(xxx=yyy, multi=3)

            s_scratch -------> c_channel
            s_scratch -------> c_channel
            s_scratch ---+---> c_channel
                         |
            s_scratch ---+


.. **ID**

.. IDの指定には、 ``id`` を使用します。
.. データフローに指定したIDを割当てます。

.. ::

..     channel_name <~ scratch_name.id()

