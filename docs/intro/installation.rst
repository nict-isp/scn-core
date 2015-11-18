=============
インストール
=============

依存ライブラリのインストール
-----------------------------

.. _Ruby: https://www.ruby-lang.org/
.. _rvm: https://rvm.io/
.. _msgpack: http://msgpack.org/
.. _msgpack-rpc: http://msgpack.org/
.. _fluent-logger-ruby: http://www.fluentd.org/
.. _bud: http://www.bloom-lang.net/bud/
.. _EventMachine: http://rubyeventmachine.com/
.. _Python: http://www.python.org
.. _pip: https://pip.pypa.io/
.. _setuptools: https://pypi.python.org/pypi/setuptools
.. _msgpack-rpc-python: http://msgpack.org/
.. _tornado: http://www.tornadoweb.org/en/stable/


SCN Coreをインストールする前に、以下のライブラリをインストールする必要があります。

#.  `Ruby`_ バージョン1.9.3。

#.  `rvm`_  Rubyのバージョン管理ツール。

#.  `msgpack`_ Ruby用の軽量で高速なシリアライズライブラリ。

#.  `msgpack-rpc`_ Ruby用のMessagePackを利用した非同期なRPCライブラリ。

#.  `fluent-logger-ruby`_ Ruby用のFluentdロガーライブラリ。

#.  `Python`_ バージョン2.7。

#.  `pip`_ 、 `setuptools`_ Pythonのパッケージ管理ツール。 `setuptools`_ は、 `pip`_ のインストール時に自動でインストールされる。

#. `msgpack-rpc-python`_ Python用のMessagePack RPCライブラリ。

#. `tornado`_ PythonのWebフレームワークおよび非同期通信ライブラリ。

..
  *   `bud`_ bloom言語を実行するためのRubyライブラリ。
  *   `EventMachine`_ イベント駆動型I/Oと軽量な並列処理を行うRubyライブラリ。


SCN Coreのインストール
-----------------------

*  GitHubリポジトリからソースコードをコピーします。

::

    $ git clone git://github.com/nict-isp/scn-core.git


*  SCN Budのインストール

::

    $ cd scn-core/lib
    $ gem install --local scn-bud/bud-0.9.5.gem


*  SCN EventMachineのインストール

::

    $ gem install --local scn-eventmachine/eventmachine-1.0.3.gem
    $ mv scn-eventmachine/ext/* ~/.rvm/gems/ruby-1.9.3-p551/gems/eventmachine-1.0.3/ext
    $ cd ~/.rvm/gems/ruby-1.9.3-p551/gems/eventmachine-1.0.3/ext
    $ make clean ; make
    $ cp rubyeventmachine.so ../lib/.


プラットフォーム別のインストール手順
-------------------------------------

Ubuntu 12.0 以上
^^^^^^^^^^^^^^^^^

*   `rvm`_ 、 `msgpack`_ 、 `msgpack-rpc`_ 、 `fluent-logger-ruby`_ のインストール。
    ::

        $  curl -L https://get.rvm.io | bash -s stable --ruby --gems=msgpack,msgpack-rpc,fluent-logger

*   `msgpack-rpc-python`_ 、 `tornado`_ のインストール。
    ::

        $ sudo pip install msgpack-rpc-python tornado


