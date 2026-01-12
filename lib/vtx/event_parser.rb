# frozen_string_literal: true

module Vtx
  class EventParser
    ESC_TIMEOUT = 0.05

    def initialize
      @native = NativeParser.new
    end

    def feed(bytes)
      @native.parse(bytes)
    end

    def pending? = @native.pending?
    def pending_timeout = ESC_TIMEOUT
    def flush = @native.flush
  end
end
