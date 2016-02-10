============
DSN description language
============

Basic structure of DSN
==============

DSN consists of ``state do`` block and ``bloom do`` block.

::

    state do
      ...
    end

    bloom do
      ...
    end


State do Block
=================

``State do`` block defines service.


**@service_name**

It searches services to match the service specified by ``discovery``, and defines the service
name by ``@service_name``.

::

    @service_name: discovery(attr_name=attr_value, attr_name=attr_value, ...)

*  ``attr_name`` : (string) Arbitrary attribute name of search target
*  ``attr_value`` : (string) Arbitrary attribute value of search target


When ``attr_name=attr_value`` is written multiple times, it will be handled as an AND condition. When there are several services that match the condition, the one that has the most resources at the node on which the service is running will be chosen.

In the following example, define the service with the value of ``category`` attribute as the ``sensor`` and the value of the ``type`` attribute of ``twitter`` as ``@twitter``.

::

    @twitter: discovery(category=sensor, type=twitter)


**scratch**

``Scratch`` defines scratch name as ``@service_name`` for a data transmission service.

::

    scratch: scratch_name, @service_name

*  ``scratch_name`` : (string) Arbitrary scratch name
*  ``@service_name`` : (string) Defined service name


In the following example, it defines ``@twitter`` service as ``s_twitter`` as a data transmission service.

::

    scratch: s_twitter, @twitter


**channel**

``Channel`` defines the channel name as ``@service_name`` as a data receiving service.

::

    channel: channel_name, @service_name

*  ``channel_name`` : (string) Arbitrary channel name
*  ``@service_name`` : (string) Defined service name

* 
In the following example, it defines ``@store`` service as ``c_store`` as a data receiving service.

::

    channel: c_store, @store



bloom do block
=================

At the ``bloom do`` , it defines the data flow and event.


Data flow
-------------

Data flow is defined as ``<~`` . When receiving data that was sent by ``scratch_name`` at ``channel_name``, describe it as follows.


::

    channel_name <~ scratch_name

*  ``channel_name`` : (string) Defined channel name
*  ``scratch_name`` : (string) Defined scratch name




In-Networking Data Processing
------------------------------

.. _M2M data format: https://github.com/nict-isp/uds-sdk/blob/master/docs/refs/m2m/v102.rst

In-Networking Data Processing can be specified to the data flow. Because the data that are sent and received by SCN-Middleware are in `M2M data format`_ , the definition for DSN description is presumed to handle the `M2M data format`_.



**Filtering**

Data filtering is defined by ``filter()``. Among the data that were sent from ``scratch_name``, only those that match the specified condition will be sent to ``channel_name``.

::

    channel_name <~ scratch_name.filter(filter_conditions)


To specify ``filter_conditions`` , use the following.


.. _conditions:

=======================================  ==============================================================================================================
Item                                     Description
=======================================  ==============================================================================================================
Arithmetic comparison                    ``>`` 、 ``>=`` 、 ``==`` 、 ``!=`` 、 ``<=`` 、 ``<``
like(data_name, regex)                   It performs pattern matching between ``data_name`` value (only string can be specified) and ``regex`` (Ruby compliance)
range(data_name, min_value, max_value)   When the arithmetic comparison between ``min_value <= data_name`` and ``data_name < max_value are`` both true, it returns true.
not                                      By adding to the head of ``like()`` and ``range()``, it means the negative of the condition.
=======================================  ==============================================================================================================


By connecting the conditions with ``&&`` or ``||`` , compound conditions can be described.
Furthermore, by enclosing the conditions between parentheses, a priority can be set.

In the following example, it only sends data to ``c_store`` when the value of ``avg_rainfall`` that is contained in the sending data of ``s_panda`` is greater than ``25``, and the value of ``latitude`` is greater than ``134.0`` and less than ``136.0`` .
::

    c_store <~ s_panda.filter(avg_rainfall >= 25 && range(latitude, 134.0, 136.0))


In the following example, it only sends data that includes the strings of ``heavy rain`` or ``wind storm`` in
the value of a ``tweet`` that is contained in the sending data of ``s_twitter`` to ``c_store``

::

    c_store <~ s_twitter.filter(like(tweet, ".*heavy rain*.") || like(tweet, ".*wind storm*."))


**Culling by time**

Culling data by time is defined by ``cull_time()``. The data sent from ``scratch_name`` are sent to ``channel_name`` after being culled by the specified time condition.

::

    channel_name <~ scratch_name.cull_time(numerator, denominator, time(time, start_time, end_time, time_interval, time_unit))

*  ``numerator`` : (integer) Numerator of culling rate
*  ``denominator`` : (integer) Denominator of culling rate
*  ``start_time`` : (yyyy/mm/ddThh:mm:ss) Start time of the data that are to be culled
*  ``end_time`` : (yyyy/mm/ddThh:mm:ss) End time of the data that are to be culled
*  ``time_interval`` : (integer) Time interval of culling
*  ``time_uni`` : (day|hour|minute|second) unit of time_interval


In the following example, it sets the value of time that is included in the sending data of ``s_panda`` to be culled, and sends the data to`` c_store`` after culling it by ``one-tenth`` with ``30 s`` in the range of ``2015/01/01/T00:00:00`` and ``2015/03/31/T23:59:59`` .

::

    c_store <~ s_panda.cull_time(1, 10, time(time, "2015/01/01T00:00:00", "2015/03/31T23:59:59", 30, "second"))



**Culling by space**

Culling data by space is defined by ``cull_space()``. The data sent from ``scratch_name`` are culled by the specified space condition and are sent to ``channel_name`` .

::

    channel_name <~ scratch_name.cull_space(numerator, denominator, space(latitude, longitude, west, south, east, north, lat_interval, long_interval))

*  ``numerator`` : (integer) Numerator of the culling rate
*  ``denominator`` : (integer) Denominator of the culling rate
*  ``west`` : (decimal fraction) Westernmost longitude of the culling space
*  ``sourh`` : (decimal fraction) Southernmost latitude of the culling space
*  ``east`` : (decimal fraction) Easternmost longitude of the culling space
*  ``north`` : (decimal fraction) Northernmost latitude of the culling space
*  ``lat_interval`` : (integer) Latitude interval of culling target
*  ``long_interval`` : (integer) Longitude interval of culling target


In the following example, it targets the value of latitude and longitude that are contained
in the sending data of ``s_panda`` to be culled, and sends to ``c_store`` the data that are culled
by ``one-tenth`` with the interval of ``0.1`` degree for ``latitude`` and the interval of ``0.3`` degree for
``longitude`` in the range of latitude ``20.0`` to ``45.0`` and longitude ``122.0`` to 153.0`` .

::

    c_store <~ s_panda.cull_space(1, 10, space(latitude, longitude, 122.0, 20.0, 153.0, 45.0, 0.1, 0.3)



**Aggregation by time and space**

Aggregation of data is defined by ``aggregate()``. It groups the data by time and space that are sent from ``scratch_name`` . It then sends the following aggregated data to ``channel_name``.


====== ===============================================
Item   Description
====== ===============================================
max    Max value of the data in the grouped range
min    Min value of the data in the grouped range
avg    Average value of the data in the grouped range
sum    Sum of the data in the grouped range
count  Count of the data in the grouped range
====== ===============================================


::

    channel_name <~ scratch_name.aggregate(data_name, time(time, start_time, end_time, time_interval, time_unit), space(latitude, longitude, west, south, east, north, lat_interval, long_interval)

*  ``data_name`` : (string) Data name that is included in the sent data from scratch_name.
*  ``start_time`` : (yyyy/mm/ddThh:mm:ss) Start time of aggregation
*  ``end_time`` : (yyyy/mm/ddThh:mm:ss) End time of aggregation
*  ``time_interval`` : (integer) Time interval of aggregation
*  ``time_uni`` : (day|hour|minute|second) Unit of time_interval
*  ``west`` : (decimal fraction) Westernmost longitude of the aggregation space
*  ``sourh`` : (decimal fraction) Southernmost latitude of the aggregation space
*  ``east`` : (decimal fraction) Easternmost longitude of the aggregation space
*  ``north`` : (decimal fraction) Northernmost latitude of the aggregation space
*  ``lat_interval`` : (integer) Latitude interval to aggregate
*  ``long_interval`` : (integer) Longitude interval to aggregate


In the following example, it aggregates the value of ave_rainfall that is contained in the
sent data of ``s_panda`` by one-tenth with ``30 s`` interval in the range of
``2015/01/01/T00:00:00`` and ``2015/03/31T23:59:59`` , and sends to ``c_store`` the data that are
aggregated by ``0.1`` degree in latitude and ``0.3`` degree in longitude in the range of latitude:
``20,0`` to ``45.0`` and longitude: ``122.0`` to ``153.0``.

::

    c_store <~ s_panda.aggregate(avg_rainfall, time(time, "2015/01/01T00:00:00", "2015/03/20T23:59:59", 30, "second"), space(latitude, longitude, 122.0, 20.0, 153.0, 45.0, 0.1, 0.3))


After aggregation, the data format will be as follows.

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

Data QoS is defined by ``qos()``. The data of ``scratch_name`` are sent by the specified QoS to ``channel_name``. However, it does not mean that it guarantees the value of the specified 

::

    channel_name <~ scratch_name.qos(qos_value)

*  ``qos_value`` : (integer) QoS value to request (unit: bps)


In the following example, it sends a request to ``c_store`` to the transmission rate of ``s_panda`` becomes at least ``1 Mbps``.

::

    c_store <~ s_panda.qos(1024000)


**Adding Meta information**

As Meta information, a table name that stores data is defined by ``meta()``. By defining ``Table=table_name`` , it stores the sending data of ``scratch_name`` in the table name specified by ``table_name`` through channel name. At this time, for the channel that is specified by ``channel_name``, it requires designation of the service for storing data.

::

    channel_name <~ scratch_name.meta(Table=table_name)

*  ``table_name`` : • (string) Arbitrary table name

In the following example, the sending data of ``s_panda`` is stored in ``PANDA_SENSORE`` table via ``c_store``.

::

    c_store <~ s_panda.meta(Table=PANDA_SENSOR)


Event
=========

Trigger
---------

Trigger of the event is defined by the following.

*  ``<+`` (Starting event)
*  ``<-`` (Ending event)
*  ``<+-`` (Starting/ending event)


When the data count that matches the ``conditions`` of conditions that are received in
``trigger_interval`` meets ``trigger_conditions``, ``channel_name`` makes ``event_name`` ``on`` in case
of ``<+`` , ``off`` in case of ``<-`` , and ``on`` or ``off`` in case of ``<+-`` .

::

    event_name <+ channel_name.trigger(trigger_interval, trigger_condtions, condiions)

*  ``event_name`` : (string) Arbitrary event name
*  ``trigger_interval`` : (integer) Interval of starting/ending event conditions
*  ``trigger_conditions`` :  :ref:`conditions<conditions>` that can be specified by conditions
*  ``conditions`` :  :ref:`conditions<conditions>` that can be specified by conditions


Event block
-----------------

Event block is to be described in the ``bloom do`` block.

``event_name.on`` do block becomes effective when ``event_name`` is ``on`` ; ``event_name.off`` do
block becomes effective when ``event_name`` is ``off`` .

::

    bloom do
        event_name.on do
          ...
        end

        event_name.off do
          ...
        end
    end


*  ``event_name`` : (string) Arbitrary event name


In the following event, when ``c_store`` receives more than ``130`` data within ``30 s``,
``heavy_rain`` event is triggered. Then ``s_twitter`` and ``s_traffic`` data are collected.


::

    bloom do
        c_store <~ s_panda.filter(avg_rainfall >= 25)
        heavy_rain <+ c_store.trigger(30, count > 130, avg_rainfall > 30)

        heavy_rain.on do
            c_store <~ s_twitter
            c_store <~ s_traffic
        end
    end



Special description method
===============

Execution definition of multiple In-Network Data Processing
-------------------------------------------

When defining several In-Network Data Processing with one data flow, connect the definition of processing with ``.`` as shown below.


::

    channel_name <~ scratch_name.filter(xxx).cull_time(xxx)

In the following example, filtering is performed first. Then culling by time is done.

::

    c_store <~ s_panda.filter(avg_rainfall >= 25).cull_time(1, 10, time(time, "2015/01/01T00:00:00", "2015/03/31T23:59:59", 30, "second"))



Definition of several @service
---------------------

Normally at ``@service_name`` , one service that matches the condition is defined. However, multiple services that match the condition are definable by designating ``multi=multi_num`` in the condition of ``discovery`` .


In the following example, by the definition of ``multi=3``, three services that match the search are defined in ``@store``. Furthermore, in the ``bloom do`` block, merely by defining ``c_store <~ s_twitter``, data flow of one to three is definable.

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


Data flow patterns by the combination of the value of ``multi`` of the data transmission source and destination service are shown below.
::

    [one to one]
        @scratch: discovery(aaa=bbb, multi=1)
        @channel: discovery(xxx=yyy, multi=1)

            s_scratch -------> c_channel

    [one to multi]
        @scratch: discovery(aaa=bbb, multi=1)
        @channel: discovery(xxx=yyy, multi=3)

                         +---> c_channel
                         |
            s_scratch ---+---> c_channel
                         |
                         +---> c_channel

    [multi to one]
        @scratch: discovery(aaa=bbb, multi=3)
        @channel: discovery(xxx=yyy, multi=1)

            s_scratch ---+
                         |
            s_scratch ---+---> c_channel
                         |
            s_scratch ---+

    [multi to multi (sending service count = receiving service count)]
        @scratch: discovery(aaa=bbb, multi=3)
        @channel: discovery(xxx=yyy, multi=3)

            s_scratch -------> c_channel
            s_scratch -------> c_channel
            s_scratch -------> c_channel

    [multi to multi (sending service count < receiving service count)]
        @scratch: discovery(aaa=bbb, multi=2)
        @channel: discovery(xxx=yyy, multi=4)

            s_scratch ---+---> c_channel
                         |
                         +---> c_channel
            s_scratch ---+---> c_channel
                         |
                         +---> c_channel

    [multi to multi (sending service count < receiving service count)]
        @scratch: discovery(aaa=bbb, multi=3)
        @channel: discovery(xxx=yyy, multi=4)

            s_scratch -------> c_channel
            s_scratch -------> c_channel
            s_scratch ---+---> c_channel
                         |
                         +---> c_channel

    [multi to multi (sending service count > receiving service count)]
        @scratch: discovery(aaa=bbb, multi=4)
        @channel: discovery(xxx=yyy, multi=2)

            s_scratch ---+---> c_channel
                         |
            s_scratch ---+
            s_scratch ---+---> c_channel
                         |
            s_scratch ---+

    [multi to multi (sending service count > receiving service count)]
        @scratch: discovery(aaa=bbb, multi=4)
        @channel: discovery(xxx=yyy, multi=3)

            s_scratch -------> c_channel
            s_scratch -------> c_channel
            s_scratch ---+---> c_channel
                         |
            s_scratch ---+


