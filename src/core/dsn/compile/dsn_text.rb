# -*- coding: utf-8 -*-
#
# Copyright (c) 2016, National Institute of Information and Communications Technology. All rights reserved. 
# GPL3, see LICENSE for more details. 
#
require_relative './dsn_define'
require_relative './dsn_format_error'

module DSN

    #= DSN記述構文クラス
    # DSN記述の構成要素の基底クラス
    #
    #@author NICT
    #
    class Syntax
        attr_reader :name
        attr_reader :dsn_text

        def initialize()
            @dsn_text = nil
        end

        # 構文開始判定処理
        #
        #@param [String] line DSN記述の文字列一行
        #@return [Syntax] DSN記述構文サブクラスのインスタンス
        #@return [nil] 構文開始条件不成立
        #
        def self.start_line?(line)
            return nil
        end

        # 構文解析処理
        #
        #@param [String] line DSN記述の文字列一行
        #@param [Integer] offset 文字列の先頭行数
        #@return [Boolean] 構文終了
        #
        def parse_line(line, offset)
            if @dsn_text.nil?
                # 1行目
                @dsn_text = DSNText.new(line, offset, "")
            else
                @dsn_text.add(line)
            end
            return false
        end

        # クラス名文字列からクラスオブジェクトを取得する
        #
        #@param [String] クラス名
        #@return [Syntax] DSN記述構文サブクラスのインスタンス
        #
        def self.get_structure_class(class_name)
            clazz = class_name.split("::").inject(Object){ |parent, name| parent.const_get(name) }
            return clazz
        end

    end

    #= DSN記述テキストクラス
    # DSN記述のテキストを取り扱う。
    #
    #@author NICT
    #
    class DSNText

        #@return [String] テキストの先頭行数
        attr_reader :line_offset
        #@return [Array<String>] テキストの配列(改行コードで、全体のテキストを要素に分割している）
        attr_reader :text
        #@return [String] 一行の文字列
        attr_reader :single_line

        #@param [String] text DSN記述の文字列
        #@param [Integer] offset 文字列の先頭行数
        #
        def initialize(text, offset, single_line="")
            @line_offset = offset
            if text.class == Array
                @text = text
            elsif text.is_a?(String)
                @text = _pre_parse(text)
            else
                @text = []
            end
            @single_line = single_line #@textから改行コードを削除し、一行の文字列としたデータ
        end

=begin
        # 変数@textとして格納している文字列の配列を空白区切りの一行の文字列として返す。
        #@return [String] 一行の文字列
        #
        def single_line()

            if @single_line.size == 0
                if @text.size > 0
                    @single_line = @text.join(" ").strip
                end
            end
            return @single_line
        end
=end

        # 変数@textとして格納している文字列の配列を空白区切りの一行の文字列として返す。
        # ただし、前後の空白は取り除く。
        #
        def convert_single_line
            #一行のみのときは、行のまま、複数行にわたる場合は、
            #先頭の行数-末尾の行数の形式で返す。
            if @text.length == 1
                line_num = "#{@line_offset}"
            else
                line_num = "#{@line_offset}-#{@line_offset + @text.length - 1}"
            end
            @line_offset = line_num
            @single_line = @text.join(" ").strip
            return self
        end

        #DSN記述解釈前処理
        # - 行毎に分割する
        # - コメントを削除する。(""内でない#以降を読み飛ばす。)
        # - 前後の空白を除去する
        #
        #@param [String] text_str 処理対象のDSNテキスト
        #@return [Array] text_arr 処理済みテキスト配列
        #
        def _pre_parse(text_str)
            text_arr = []
            text_str.each_line do |line|
                left_string = ""
                comment = false
                DSNText.not_string_chars(line, false) do |chars, outside|
                    if outside
                        if not (idx = chars.index("#")).nil?
                            left_string << chars.slice(0, idx)
                            comment = true
                        end
                    end
                    if not comment
                        left_string << chars
                    end
                end
                text_arr << left_string.strip
            end
            return text_arr
        end

        #DSNテキストを二つのDSNテキストに二分割する。
        #
        #@param [DSNText] dsn_text 分割対象のDSNテキスト
        #@param [String] delimiter 区切り文字
        #@param [Integer] size 分割サイズ
        #@return [Array<DSNText>] 分割した文字列を含むDSNText
        #
        def self.split_dsn_text(dsn_text,delimiter,size=0)
            array = split(dsn_text.single_line, delimiter, size)
            return array.map { |line| DSNText.new(dsn_text.text, dsn_text.line_offset, line)}
        rescue => err
            log_error $!
            raise DSNFormatError.new(err.message, dsn_text)
        end

        #DSNテキストを二つのDSNテキストに二分割する。
        #
        #@param [DSNText] dsn_text 分割対象のDSNテキスト
        #@param [String] delimiter 区切り文字
        #@return [Array<DSNText>] 分割した文字列を含むDSNText
        #
        def self.split_two_dsn_text(dsn_text,delimiter)
            return split_dsn_text(dsn_text,delimiter,2)
        end

        #構文内の「:」の区切り文字で分解する。
        #
        #@param [DSNText] dsn_text 分割対象の文字列
        #@return [Array<DSNText>] 区切り文字で分割された文字列の配列
        #
        def self.split_two_sentence( dsn_text )
            return split_two_dsn_text( dsn_text, STATE_SENTENCE_DELIMITER)
        end

        #構文内の「=」の区切り文字で分解する。
        #
        #@param [DSNText] dsn_text 分割対象の文字列
        #@return [Array<DSNText>] 区切り文字で分割された文字列の配列
        #
        def self.split_two_attr( dsn_text )
            return split_two_dsn_text( dsn_text, SERVICE_ATTR_DELIMITER)
        end

        #構文内の「,」の区切り文字で分解する。
        #
        #@param [DSNText] dsn_text 分割対象の文字列
        #@return [Array<DSNText>] 区切り文字で分割された文字列の配列
        #
        def self.split_two_comma( dsn_text )
            return split_comma(dsn_text,2)
        end

        #構文内の「,」の区切り文字で分解する。
        #
        #@param [DSNText] dsn_text 分割対象の文字列
        #@param [Int] size 分割する数(0の場合は、すべて分割する。)
        #@return [Array<DSNText>] 区切り文字で分割された文字列の配列
        #
        def self.split_comma( dsn_text, size=0)
            return split_dsn_text( dsn_text, COMMUNICATION_DELIMITER,size)
        end

        #構文内の「>~」の区切り文字で分解する。
        #
        #@param [DSNText] dsn_text 分割対象の文字列
        #@return [Array<DSNText>] 区切り文字で分割された文字列の配列
        #
        def self.split_two_trans( dsn_text)
            return split_two_dsn_text( dsn_text, TRANSMISSION_DELIMITER)
        end

        #構文内の「<+」の区切り文字で分解する。
        #
        #@param [DSNText] dsn_text 分割対象の文字列
        #@return [Array<DSNText>] 区切り文字で分割された文字列の配列
        #
        def self.split_two_on_trigger( dsn_text )
            return split_two_dsn_text( dsn_text, TRIGGER_ON_DELIMITER)
        end

        #構文内の「<-」の区切り文字で分解する。
        #
        #@param [DSNText] dsn_text 分割対象の文字列
        #@return [Array<DSNText>] 区切り文字で分割された文字列の配列
        #
        def self.split_two_off_trigger( dsn_text )
            return split_two_dsn_text( dsn_text, TRIGGER_OFF_DELIMITER)
        end

        #構文内の「,」の区切り文字で分解する。
        #
        #@param [String] dsn_text 分割対象の文字列
        #@param [Int] size 分割する数(0の場合は、すべて分割する。)
        #@return [Array<String>] 区切り文字で分割された文字列の配列
        #
        def self.split_string_comma( dsn_text, size=0)
            return split( dsn_text, COMMUNICATION_DELIMITER,size)
        end

        #構文内の「=」の区切り文字で分解する。
        #
        #@param [String] dsn_text 分割対象の文字列
        #@return [Array<String>] 区切り文字で分割された文字列の配列
        #
        def self.split_string_two_attr( dsn_text )
            return split( dsn_text, SERVICE_ATTR_DELIMITER,2)
        end

        # 指定した文字列を区切り文字で分解する。ただし、
        # 前後の空白は取り除く。
        # また、ダブルクォート内と()内の場合は
        # 分割を行わない(区切り文字を含む文字列扱い)
        #
        #@param [String] text 分割対象の文字列
        #@param [String] delimiter 分割時の区切り文字
        #@param [Int] size 分割する数(0の場合は、すべて分割する。)
        #@return [Array<String>] 区切り文字で分割された文字列の配列
        #@note textからコメントは除去されていること
        #
        def self.split(text, delimiter, size=0, error_raise=true)
            return [ text.strip ] if size == 1
            sep_array  = []
            sep_string = ""
            sep_count  = size
            not_brackets_chars(text, error_raise) do |chars, outside|

                if outside
                    if size == 0 || sep_count > 1
                        temp_sep = chars.split(delimiter, sep_count)
                        if temp_sep.size > 1
                            # 先頭と末尾は、前後の分割文字列と繋がる
                            # text => "aaa, (bbb, ccc), ddd"
                            # not_brackets_chars + split(/,/)
                            # => ["aaa", " (", "bbb, ccc", ")", "", " ddd" ]
                            # sep_array => ["aaa", "(bbb, ccc)", "ddd" ]
                            sep_string << temp_sep.shift
                            sep_array << sep_string.strip

                            sep_string = temp_sep.pop
                            temp_sep.each do |temp|
                                sep_array << temp.strip
                            end
                            sep_count -= temp_sep.size
                        else
                            sep_string << chars
                        end
                    else
                        sep_string << chars
                    end
                else
                    sep_string << chars
                end
            end
            sep_array << sep_string.strip if sep_string.size > 0

            return sep_array
        end

        #インスタンスの変数に一行追加する。
        #
        #@param [String] line 追加する文字列(1行)
        #
        def add(line)
            @text << line
        end

        #インスタンスの変数から一行取り除く。
        #
        #@param [Fixnum] index
        #
        def delete(index)
            if index == 0
                @line_offset += 1
            end
            @text.delete_at(index)
        end

        #DSNTextの配列を結合する。
        def self.join(array,delimiter)
            texts = array.map{|text|text.single_line}
            join_text = texts.join(delimiter)
            return DSNText.new(join_text, array[0].line_offset, join_text)
        end

        # DSN::Conditions から流用。使用箇所の最上位で共通部品として定義し直す。
        # 文字列を区切って繰り返す。
        # その際、ダブルクォート内の文字列かどうかの情報を付与する。
        #
        #@param [String] text 走査対象の文字列
        #@param [Boolean] error_raise エラー発生有無
        #@yieldparam [String] chars 文字列から取り出した文字列
        #@yieldparam [Boolean] outside ダブルクォート外の時、true
        #@retrun [void]
        #@raise [DSNInternalFormatError] 構文として正しくないデータが設定された。
        #@raise [DSNFormatError] 指定できない文字列が設定された。
        #
        def self.not_string_chars(text, error_raise=true)
            quoted  = false
            escaped = false

            begin
                text.split(/(\"|\\")/).each do |chars|
                    if quoted
                        yield(chars, !quoted)   # "の終端をfalseで返す

                        if chars == '"'
                            quoted  = false
                        elsif chars == '\"'
                            # エスケープ(文字列内")
                        end
                    else
                        if chars == '"'
                            quoted  = true
                        elsif chars == '\"'
                            raise DSNInternalFormatError, "文字列外に\\\"は使用できません。" if error_raise
                        end

                        yield(chars, !quoted)   # "の始端をfalseで返す
                    end
                end
                if quoted
                    raise DSNInternalFormatError, "文字列の終端がありません。" if error_raise
                end
            rescue  => err
                raise DSNFormatError.new(ErrorMessage::ERR_DATANAME_FORMAT, text)
            end
        end

        # 文字列を区切って繰り返す。
        # その際、括弧内またはダブルクォート内の文字列かどうかの情報を付与する。
        #
        #@param [String] text 走査対象の文字列
        #@yieldparam [String] chars 文字列から取り出した文字列
        #@yieldparam [Boolean] outside 括弧・ダブルクォート外の時、true
        #@retrun [void]
        #
        def self.not_brackets_chars(text, error_raise=true)
            brackets = []
            not_string_chars(text, error_raise) do |not_string, outside|
                if outside
                    not_string.split(/(\(|\)|\[|\])/).each do |chars|
                        if chars == "("
                            brackets << ")"  # 括弧の終端を登録（スタックする）
                            yield(chars, false)
                        elsif chars == "["
                            brackets << "]"  # 括弧の終端を登録（スタックする）
                            yield(chars, false)
                        else
                            if brackets.size == 0
                                if chars == ")" || chars == "]"
                                    raise DSNInternalFormatError, "括弧の始端がありません。" if error_raise
                                end

                                yield(chars, true)
                            else
                                yield(chars, false)

                                if chars == brackets.last
                                    brackets.pop     # 括弧の終端を削除
                                end
                            end
                        end
                    end
                else
                    yield(not_string, false)
                end
            end

            if brackets.size > 0
                raise DSNInternalFormatError, "括弧の終端がありません。" if error_raise
            end
        end

        # 文字列内文字を置換して返却
        #
        #@param [String] text 走査対象の文字列
        #@param [String] replace 置換文字列
        #@return [String] 置換後の文字列
        #@note 文字列の外側のみ構文一致判定する
        #
        def self.replace_inside_string(text, replace="")
            remove_text = ""
            not_string_chars(text) do |chars, outside|
                if outside
                    remove_text << chars
                elsif chars == '"'
                    remove_text << chars
                else
                    remove_text << replace
                end
            end
            return remove_text
        end

        # 文字列内の括弧が閉じているか検出する。
        #
        #@param [String] text 走査対象の文字列
        #@param [String] replace 置換文字列
        #@return [Boolean] 置換後の文字列
        #@note 文字列の外側のみ構文一致判定する
        #
        def self.close_small_brackets?(text)
            brackets_count = 0
            not_string_chars(text, true) do |not_string, outside|
                if outside
                    not_string.each_char do |char|
                        if char == "("
                            brackets_count += 1
                        elsif char == ")"
                            brackets_count -= 1
                        end
                    end
                else
                    # nop
                end
            end

            if brackets_count == 0
                return true
            elsif brackets_count > 0
                return false
            else #brackets_count < 0 ： 閉じ括弧が余分
                raise DSNInternalFormatError, "Too many close brackets.\")\"."
            end
        end
    end # end of class
end # end of module
