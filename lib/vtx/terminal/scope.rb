# frozen_string_literal: true

module Vtx
  class Terminal
    class Scope
      def initialize(terminal)
        @terminal = terminal
        @restore = []
      end

      def raw_mode
        @terminal.enable_raw_mode
        @restore << :disable_raw_mode

        self
      end

      def alternate_screen
        @terminal.enter_alternate_screen
        @restore << :leave_alternate_screen

        self
      end

      def mouse_capture(...)
        @terminal.enable_mouse_capture(...)
        @restore << :disable_mouse_capture

        self
      end

      def bracketed_paste
        @terminal.enable_bracketed_paste
        @restore << :disable_bracketed_paste

        self
      end

      def focus_events
        @terminal.enable_focus_events
        @restore << :disable_focus_events

        self
      end

      def hidden_cursor
        @terminal.hide_cursor
        @restore << :show_cursor

        self
      end

      def cursor_style(...)
        @terminal.cursor_style(...)
        @restore << :reset_cursor_style

        self
      end

      def run
        yield @terminal
      ensure
        @restore.reverse_each { |method| @terminal.send(method) }
        @terminal.flush
      end
    end
  end
end
