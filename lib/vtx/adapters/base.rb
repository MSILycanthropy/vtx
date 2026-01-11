# frozen_string_literal: true

require "io/wait"

module Vtx
  module Adapters
    # Base adapater contract for terminal backends
    #
    # Adapters provide the low-level interface between I/O and the
    # terminal abstraction. The default ANSI adapter uses escape
    # sequences, but this contract allows for different
    # implementations (Windows Console, mock adapters, etc)
    #
    # All methods are unimplemented by default, aside from `read`, `write`
    # and `flush`. So that implementors don't forget things <3
    #
    # @ example Custom adapter
    #   class MyAdapter < Vtx::Adapters::Base
    #     include Vtx::Adapters::AnsiSequences
    #
    #     # ... implement all the methods
    #   end
    #
    class Base
      def initialize(input:, output:)
        @input = input
        @output = output
      end

      def write(...) = @output.write(...)

      def read(timeout: nil)
        return unless @input.wait_readable(timeout)

        @input.read_nonblock(4096)
      rescue IO::WaitReadable, EOFError
        nil
      end

      def flush = @output.flush

      def enable_raw_mode = raise NotImplementedError
      def disable_raw_mode = raise NotImplementedError
      def enter_alternate_screen = raise NotImplementedError
      def leave_alternate_screen = raise NotImplementedError
      def enable_mouse_capture(mode) = raise NotImplementedError
      def disable_mouse_capture = raise NotImplementedError
      def enable_bracketed_paste = raise NotImplementedError
      def disable_bracketed_paste = raise NotImplementedError
      def enable_focus_events = raise NotImplementedError
      def disable_focus_events = raise NotImplementedError

      def capabilities = raise NotImplementedError
      def size = raise NotImplementedError

      def move_to(row, col) = raise NotImplementedError
      def move_up(n = 1) = raise NotImplementedError
      def move_down(n = 1) = raise NotImplementedError
      def move_forward(n = 1) = raise NotImplementedError
      def move_back(n = 1) = raise NotImplementedError
      def move_to_next_line(n = 1) = raise NotImplementedError
      def move_to_prev_line(n = 1) = raise NotImplementedError
      def move_to_column(col) = raise NotImplementedError
      def move_to_row(row) = raise NotImplementedError
      def move_home = raise NotImplementedError
      def save_cursor = raise NotImplementedError
      def restore_cursor = raise NotImplementedError
      def show_cursor = raise NotImplementedError
      def hide_cursor = raise NotImplementedError

      def clear = raise NotImplementedError
      def clear_below = raise NotImplementedError
      def clear_above = raise NotImplementedError
      def clear_line = raise NotImplementedError
      def clear_line_right = raise NotImplementedError
      def clear_line_left = raise NotImplementedError
      def scroll_up(n = 1) = raise NotImplementedError
      def scroll_down(n = 1) = raise NotImplementedError
      def set_scroll_region(top, bottom) = raise NotImplementedError
      def reset_scroll_region = raise NotImplementedError
      def insert_lines(n = 1) = raise NotImplementedError
      def delete_lines(n = 1) = raise NotImplementedError
      def insert_chars(n = 1) = raise NotImplementedError
      def delete_chars(n = 1) = raise NotImplementedError
      def erase_chars(n = 1) = raise NotImplementedError

      def reset_style = raise NotImplementedError
      def style(**options) = raise NotImplementedError

      def title(title) = raise NotImplementedError
      def icon_name(name) = raise NotImplementedError

      def copy_to_clipboard(text, target: :clipboard) = raise NotImplementedError
      def request_clipboard(target: :clipboard) = raise NotImplementedError

      def hyperlink_start(url, id: nil) = raise NotImplementedError
      def hyperlink_end = raise NotImplementedError
      def hyperlink(url, text, id: nil) = raise NotImplementedError

      def bell = raise NotImplementedError
      def notify(title, body: nil) = raise NotImplementedError

      def query(request, timeout: 1.0, &parser) = raise NotImplementedError
      def cursor_position(timeout: 1.0) = raise NotImplementedError
      def device_attributes(timeout: 1.0) = raise NotImplementedError

      def close = raise NotImplementedError
    end
  end
end
