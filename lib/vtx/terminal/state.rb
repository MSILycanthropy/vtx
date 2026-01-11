# frozen_string_literal: true

module Vtx
  class Terminal
    class State
      def initialize
        @raw_mode = false
        @alternate_screen = false
        @mouse_capture = nil
        @bracketed_paste = false
        @focus_events = false
        @cursor_visible = true
        @size = nil
      end

      attr_accessor :raw_mode,
        :alternate_screen,
        :mouse_capture,
        :bracketed_paste,
        :focus_events,
        :cursor_visible,
        :size

      def raw_mode? = @raw_mode
      def alternate_screen? = @alternate_screen
      def bracketed_paste? = @bracketed_paste
      def focus_events? = @focus_events
      def cursor_visible? = @cursor_visible
    end
  end
end
