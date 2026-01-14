# frozen_string_literal: true

require "bundler/setup"
require "vtx"
require "English"

module Vtx
  class MockIO
    def initialize
      @input_buffer = String.new(encoding: Encoding::UTF_8)
      @output_buffer = String.new(encoding: Encoding::UTF_8)
      @raw = false
      @echo = true
      @closed = false
      @eof = false
      @mutex = Mutex.new
    end

    def raw? = @raw
    def echo? = @echo
    def closed? = @closed
    def eof? = @eof && @input_buffer.empty?
    def tty? = true

    def raw!
      @raw = true
      self
    end

    def cooked!
      @raw = false
      self
    end

    attr_writer :echo

    def read(length = nil)
      @mutex.synchronize do
        return if @input_buffer.empty? && @eof

        if length.nil?
          result = @input_buffer.dup
          @input_buffer.clear
          result
        else
          @input_buffer.slice!(0, length)
        end
      end
    end

    def readpartial(length, outbuf = nil)
      @mutex.synchronize do
        raise EOFError, "end of file reached" if @input_buffer.empty? && @eof

        data = @input_buffer.slice!(0, length)
        if outbuf
          outbuf.replace(data)
        else
          data
        end
      end
    end

    def read_nonblock(length, outbuf = nil, exception: true)
      @mutex.synchronize do
        if @input_buffer.empty?
          raise EOFError, "end of file reached" if @eof
          if exception
            raise IO::WaitReadable, "read would block"
          else
            return :wait_readable
          end
        end

        data = @input_buffer.slice!(0, length)
        if outbuf
          outbuf.replace(data)
        else
          data
        end
      end
    end

    def wait_readable(timeout = nil)
      !@input_buffer.empty? || @eof
    end

    def getc
      read(1)
    end

    def getbyte
      read(1)&.ord
    end

    def gets(sep = $INPUT_RECORD_SEPARATOR, limit = nil)
      @mutex.synchronize do
        return if @input_buffer.empty? && @eof

        if sep.nil?
          result = @input_buffer.dup
          @input_buffer.clear
          return result
        end

        idx = @input_buffer.index(sep)
        if idx
          return @input_buffer.slice!(0, idx + sep.length)
        elsif @eof
          result = @input_buffer.dup
          @input_buffer.clear
          return result.empty? ? nil : result
        end

        nil
      end
    end

    def write(data)
      @mutex.synchronize do
        raise IOError, "closed stream" if @closed

        data = data.to_s
        @output_buffer << data
        data.bytesize
      end
    end

    def <<(data)
      write(data)
      self
    end

    def print(*args)
      args.each { |arg| write(arg.to_s) }
      nil
    end

    def puts(*args)
      ending = @raw ? "\r\n" : "\n"

      if args.empty?
        write(ending)
      else
        args.each do |arg|
          line = arg.to_s
          write(line)
          write(ending) unless line.end_with?("\n", "\r\n")
        end
      end
      nil
    end

    def flush
      self
    end

    def close
      @closed = true
      self
    end

    def simulate_input(data)
      @mutex.synchronize do
        unless @raw
          data = data.gsub("\r\n", "\n").gsub("\r", "\n")
        end

        @input_buffer << data
      end
      self
    end

    def simulate_key(key)
      sequence = case key
      when :up then "\e[A"
      when :down then "\e[B"
      when :right then "\e[C"
      when :left then "\e[D"
      when :enter then @raw ? "\r" : "\n"
      when :escape then "\e"
      when :backspace then "\x7f"
      when :tab then "\t"
      when String then key
      else key.to_s
      end

      simulate_input(sequence)
    end

    def simulate_eof
      @eof = true
      self
    end

    def output
      @output_buffer.dup
    end

    def drain_output
      @mutex.synchronize do
        result = @output_buffer.dup
        @output_buffer.clear
        result
      end
    end

    def clear_output
      @mutex.synchronize { @output_buffer.clear }
      self
    end

    def output_includes?(str)
      @output_buffer.include?(str)
    end

    def winsize
      [24, 80]
    end

    def winsize=(size)
    end
  end
end

io = Vtx::MockIO.new
term = Vtx::Terminal.new(input: io, output: io)

term.enable_raw_mode
term.enter_alternate_screen
term.hide_cursor

term.move_to(5, 10)
term.print("Hello from VTX!", foreground: :green, bold: true)

term.move_to(7, 10)
term.print("Press any key...", foreground: :dim)

term.flush

puts "=== Output buffer ==="
puts io.output.inspect

io.simulate_key(:up)
io.simulate_key(:enter)
io.simulate_input("hello")

term.flush

while (event = term.read_event)
  puts "Event: #{event.inspect}"
end

term.close
