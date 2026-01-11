# frozen_string_literal: true

module Vtx
  COLORS = [:none, :basic, :extended, :true_color].freeze

  # Light capability detection based on environment variables.
  #
  # No terminal querying — keeps things simple and fast. Detection is based on
  # TERM, COLORTERM, TERM_PROGRAM, and NO_COLOR environment variables.
  #
  # @example
  #   caps = Capabilities.detect
  #   caps.colors      # => :true_color
  #   caps.true_color? # => true
  #
  # @example Manual override
  #   caps = Capabilities.new(colors: :basic)
  #
  class Capabilities
    def initialize(colors: :basic)
      raise ArgumentError, "Invalid color level: #{colors}" unless COLORS.include?(colors)

      @colors = colors
    end

    attr_reader :colors

    class << self
      def detect(term: ENV["TERM"],
        colorterm: ENV["COLORTERM"],
        term_program: ENV["TERM_PROGRAM"],
        no_color: ENV.key?("NO_COLOR"))
        return new(colors: :none) if no_color

        detect_from_colorterm(colorterm) ||
          detect_from_program(term_program) ||
          detect_from_colorterm(term) ||
          new(colors: :basic)
      end

      private

      def detect_from_colorterm(colorterm)
        return if colorterm.nil? || colorterm.empty?
        return unless ["truecolor", "24bit"].include?(colorterm.downcase)

        new(colors: :true_color)
      end

      def detect_from_program(program)
        return if program.nil? || program.empty?

        case program.downcase
        when "iterm.app", "apple_terminal", "hyper", "vscode"
          new(colors: :true_color)
        end
      end

      def detect_from_term(term)
        return if term.nil? || term.empty?

        term_lower = term.downcase

        return new(colors: :true_color) if term_lower.include?("truecolor") || term_lower.include?("24bit")
        return new(colors: :extended) if term_lower.include?("256color")

        new(colors: :basic) if term_lower.include?("color") || term_lower.start_with?("xterm", "screen", "vt100", "rxvt", "linux")
      end
    end

    def color? = @colors != :none
    def true_color? = @colors == :true_color
    def extended_color? = @colors == :extended || true_color?
  end
end
