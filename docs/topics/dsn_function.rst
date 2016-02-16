==========================
Adding a new DSN function
==========================

To add a new DSN function, you need to add the interpretation processing and execution processing of the DSN description.
In the following DSN description as an example, it describes the procedure to add a function.

::

    c1 <~ s1.sample(arg1, arg2)


Interpretaion processing
=========================

Place the basic code of the following as ``core/dsn/compile/sample_method.rb``, and then implement the necessary processing.
``sample_method.rb`` , ``sample`` , ``arg1`` , ``arg2`` , please change to the appropriate name.


.. code-block:: ruby

    # -*- coding: utf-8 -*-
    require_relative './base_method'

    module DSN

        #= SampleMethod class
        #
        class SampleMethod < BaseMethod
            # method name
            METHOD_NAME = "sample"

            def initialize(arg1, arg2)
                @arg1 = arg1
                @arg2 = arg2
            end

            # It determines whether or not this method.
            def self.match?(text)
                return BaseMethod::match?(text,METHOD_NAME)
            end

            # To analyze the syntax.
            #
            #@param [DSNtext] text Strings of method
            #@return [Array<String>] Array of arguments of the method
            #@raise [DSNFormatError] If as a method not in the correct format
            #
            def self.parse(text)
                format = nil
                args = BaseMethod.parse(text, METHOD_NAME, format)

                arg1 = args[1].single_line
                arg2 = args[0].single_line

                # verification code will be implemented

                return StringMethod.new(arg1, arg2)
            end

            # It is converted into an intermediate code.
            def to_hash()
                return {
                    KEY_SAMPLE => {
                        KEY_ARG1 => @arg1,
                        KEY_ARG2 => @arg2
                    }}
            end
        end
    end


Please add the following to the top of ``core/dsn/compile/transmission.rb`` and the following to the case statement in ``_parse_method()``.


.. code-block:: ruby

    require_relative './sample_method.rb'

                :

        def _parse_method(processing)

                :

            when SampleMethod.match?(proc_text)
                method["processing"] = SampleMethod.parse(proc_text)


Please add the following in ``module DSN`` of ``core/dsn/compile/dsn_define.rb`` .

.. code-block:: ruby

    KEY_SAMPLE = sample
    KEY_ARG1   = arg1
    KEY_ARG2   = arg2



execution processing
=====================

Place the basic code of the following as ``core/dsn/processing/sample.rb``, and then implement the necessary processing.
``sample.rb`` , ``sample`` , ``arg1`` , ``arg2`` , please change to the appropriate name.


.. code-block:: ruby

    #-*- coding: utf-8 -*-
    require_relative './processing'

    #= SampleOperation class
    #
    class SampleOperation < Processing

        #@param [Hash] conditions Intermediate processing request
        #
        def initialize(conditions)
            super
            @arg1 = conditions["arg1"]
            @arg2 = conditions["arg2"]
        end

        # execution of the operation
        #
        #@param [Hash] processing_data Intermediate processing data
        #@return data After the operation execution
        #
        def execute(processing_data)
            return processing_values(processing_data, :each) { |value|

                # processing code will be implemented

            }
        end
    end

Please add the following to the top of ``core/dsn/processing/processing_factory.rb`` and the following to the case statement in ``get_instance()``.


.. code-block:: ruby
    require_relative './sample'

                :

        def self.get_instance(processing)

                :

            when "sample"
                proccesing = SampleOperation.new(param)

