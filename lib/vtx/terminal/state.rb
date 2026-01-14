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
        @echo = true
        @size = nil
      end

      attr_accessor :raw_mode,
        :alternate_screen,
        :mouse_capture,
        :bracketed_paste,
        :focus_events,
        :cursor_visible,
        :echo,
        :size

      def mouse_capture? = !@mouse_capture.nil?
      def raw_mode? = @raw_mode
      def alternate_screen? = @alternate_screen
      def bracketed_paste? = @bracketed_paste
      def focus_events? = @focus_events
      def echo? = @echo
      def cursor_visible? = @cursor_visible
    end
  end
end
