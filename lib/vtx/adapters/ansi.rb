# frozen_string_literal: true

require "io/console"

module Vtx
  module Adapters
    # ANSI terminal adapter for Unix-like systems.
    #
    # Uses standard ANSI/VT escape sequences for terminal control and
    # io/console for raw mode switching.
    #
    class Ansi < Base
      include AnsiSequences

      def initialize(input:, output:)
        super

        @raw_mode = false
      end

      def raw_mode? = @raw_mode

      def enable_raw_mode
        return self unless @input.tty?
        return self if raw_mode?

        @input.raw!
        @raw_mode = true
        self
      end

      def disable_raw_mode
        return self unless @input.tty?
        return self unless raw_mode?

        @input.cooked!
        @raw_mode = false
        self
      end

      def capabilities
        @capabilities ||= Capabilities.detect
      end

      def size
        return unless @input.tty?

        if @output.respond_to?(:winsize)
          return @output.winsize
        end

        rows = ENV["LINES"]&.to_i
        cols = ENV["COLUMNS"]&.to_i

        [rows, cols]
      end

      def query(request, timeout: 1.0)
        write(request)
        flush

        buffer = String.new(encoding: Encoding::ASCII_8BIT)
        deadline = Time.now + timeout

        loop do
          remaining = deadline - Time.now

          break if remaining <= 0

          chunk = read(timeout: remaining)

          break if chunk.nil?

          buffer << chunk

          if (result = yield(buffer))
            return result
          end
        end

        nil
      end

      def cursor_position(timeout: 1.0)
        query("\e[6n", timeout:) do |buffer|
          if buffer =~ /\e\[(\d+);(\d+)R/
            [::Regexp.last_match(1).to_i - 1, ::Regexp.last_match(2).to_i - 1]
          end
        end
      end

      def device_attributes(timeout: 1.0)
        query("\e[c", timeout:) do |buffer|
          if buffer =~ /\e\[\?(\d+(?:;\d+)*)c/
            ::Regexp.last_match(1).split(";").map(&:to_i)
          end
        end
      end

      def close
        unsubscribe_resize
        disable_raw_mode
        flush
      end
    end
  end
end
