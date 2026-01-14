# frozen_string_literal: true

# A minimal Ruby REPL to showcase Vtx::Terminal

require "bundler/setup"
require "vtx"

module Vtx
  class LineEditor
    attr_reader :history

    def initialize(terminal)
      @terminal = terminal
      @history = []
    end

    def read_line(prompt: "")
      @prompt = prompt
      @buffer = String.new(encoding: Encoding::UTF_8)
      @cursor = 0
      @history_index = @history.length
      @stashed_buffer = nil

      @terminal.scoped.raw_mode.run do
        render

        loop do
          event = @terminal.read_event

          case event
          in Key(code: :enter)
            @terminal.puts
            @history << @buffer.dup unless @buffer.empty?
            return @buffer
          in Key(code: :char, char:, ctrl: false, alt: false)
            insert(char)
          in Key(code: :backspace)
            backspace
          in Key(code: :delete)
            delete
          in Key(code: :left)
            move_left
          in Key(code: :right)
            move_right
          in Key(code: :up)
            history_prev
          in Key(code: :down)
            history_next
          in Key(code: :home) | Key(code: :char, char: "a", ctrl: true)
            move_home
          in Key(code: :end) | Key(code: :char, char: "e", ctrl: true)
            move_end
          in Key(code: :char, char: "c", ctrl: true)
            raise Interrupt
          in Key(code: :char, char: "d", ctrl: true)
            return if @buffer.empty?
          in Key(code: :char, char: "u", ctrl: true)
            kill_line
          in Key(code: :char, char: "k", ctrl: true)
            kill_to_end
          in Key(code: :char, char: "w", ctrl: true)
            kill_word
          else
          end
        end
      end
    end

    private

    def insert(char)
      @buffer.insert(@cursor, char)
      @cursor += 1
      render
    end

    def backspace
      return if @cursor.zero?

      @cursor -= 1
      @buffer.slice!(@cursor)
      render
    end

    def delete
      return if @cursor >= @buffer.length

      @buffer.slice!(@cursor)
      render
    end

    def move_left
      return if @cursor.zero?

      @cursor -= 1
      render
    end

    def move_right
      return if @cursor >= @buffer.length

      @cursor += 1
      render
    end

    def move_home
      @cursor = 0
      render
    end

    def move_end
      @cursor = @buffer.length
      render
    end

    def kill_line
      return if @cursor.zero?

      @buffer.slice!(0, @cursor)
      @cursor = 0
      render
    end

    def kill_to_end
      return if @cursor >= @buffer.length

      @buffer.slice!(@cursor..)
      render
    end

    def kill_word
      return if @cursor.zero?

      pos = @cursor
      pos -= 1 while pos > 0 && @buffer[pos - 1] == " "
      pos -= 1 while pos > 0 && @buffer[pos - 1] != " "

      @buffer.slice!(pos, @cursor - pos)
      @cursor = pos
      render
    end

    def history_prev
      return if @history.empty?
      return if @history_index.zero?

      @stashed_buffer = @buffer.dup if @history_index == @history.length

      @history_index -= 1
      @buffer = @history[@history_index].dup
      @cursor = @buffer.length
      render
    end

    def history_next
      return if @history_index >= @history.length

      @history_index += 1

      @buffer = if @history_index == @history.length
        @stashed_buffer || String.new(encoding: Encoding::UTF_8)
      else
        @history[@history_index].dup
      end

      @cursor = @buffer.length
      render
    end

    def render
      @terminal.move_to_column(0)
      @terminal.clear_line_right
      @terminal.print(@prompt)
      @terminal.print(@buffer)
      @terminal.move_to_column(@prompt.length + @cursor)
      @terminal.flush
    end
  end
end

terminal = Vtx::Terminal.new
editor = Vtx::LineEditor.new(terminal)

editor.history << "1 + 1"
editor.history << "puts 'hello'"

begin
  context = binding

  loop do
    line = editor.read_line(prompt: "> ")

    break if line.nil?

    result = begin
      context.eval(line)
    rescue => e
      puts "#{e.class}: #{e.message}"

      next
    end

    puts "Result: #{result.inspect}"
  end
rescue Interrupt
  puts "\nBye!"
end
