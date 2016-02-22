=============
Installation
=============

Install dependent libraries
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
.. _java: http://www.oracle.com/technetwork/java/index.html
.. _RJB: http://www.artonx.org/collabo/backyard/?RubyJavaBridge

Before installing SCN Core, the following libraries must be installed.

#.  `Ruby`_ version 1.9.3.

#.  `rvm`_ Version management tool of Ruby

#.  `msgpack`_ Light and high-speed serial library for Ruby

#.  `msgpack-rpc`_ Asynchronous RPC library using MessagePack of Ruby

#.  `fluent-logger-ruby`_ Fluentd Logger library for Ruby

#.  `Python`_ Version 2.7

#.  `pip`_ , `setuptools`_ Package management tool of Python. `setuptools`_ will be installed automatically when `pip`_ is installed.

#. `msgpack-rpc-python`_ MessagePack RPC library for Python

#. `tornado`_ Web framework and asynchronous communication library of Python

#. `java`_ JDK8

#. `RJB`_ RJB is a bridge program that connect between Ruby and Java with Java Native Interface.


Installation of SCN Core
------------------------

*  Copy source code from GitHub repository.

::

    $ git clone git://github.com/nict-isp/scn-core.git


*  Install SCN Bud

::

    $ cd scn-core/lib
    $ gem install --local scn-bud/bud-0.9.5.gem


*  Install SCN EventMachine

::

    $ gem install --local scn-eventmachine/eventmachine-1.0.3.gem
    $ mv scn-eventmachine/ext/* ~/.rvm/gems/ruby-1.9.3-p551/gems/eventmachine-1.0.3/ext
    $ cd ~/.rvm/gems/ruby-1.9.3-p551/gems/eventmachine-1.0.3/ext
    $ make clean ; make
    $ cp rubyeventmachine.so ../lib/.


Installation procedure for a platform
-------------------------------------

Ubuntu 12.0 or above
^^^^^^^^^^^^^^^^^^^^

*   Install `rvm`_ 、 `msgpack`_ 、 `msgpack-rpc`_ 、 `fluent-logger-ruby`_ .
    ::

        $  curl -L https://get.rvm.io | bash -s stable --ruby --gems=msgpack,msgpack-rpc,fluent-logger

*   Install `msgpack-rpc-python`_ 、 `tornado`_ .
    ::

        $ sudo pip install msgpack-rpc-python tornado
