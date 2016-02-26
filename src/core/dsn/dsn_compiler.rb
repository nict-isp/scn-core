# -*- coding: utf-8 -*-
require_relative './compile/dsn'
require_relative './compile/dsn_text'

#= DSN description interpretation class
#
#@author NICT
#
class DSNCompiler

    #@param [String] dsn_desc  DSN description
    #@return [JSON] Intermediate code
    #
    def self.compile(dsn_desc)
        dsn_text = DSN::DSNText.new(dsn_desc, 0)
        dsn      = DSN::DSN.parse(dsn_text, "dummy")
        dsn_hash = dsn.to_hash
        return dsn_hash
    end
end
