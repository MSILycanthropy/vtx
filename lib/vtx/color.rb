# frozen_string_literal: true

module Vtx
  module Color
    BASIC = {
      black: 0,
      red: 1,
      green: 2,
      yellow: 3,
      blue: 4,
      magenta: 5,
      cyan: 6,
      white: 7,
      default: 9,
    }.freeze

    BRIGHT = {
      bright_black: 0,
      bright_red: 1,
      bright_green: 2,
      bright_yellow: 3,
      bright_blue: 4,
      bright_magenta: 5,
      bright_cyan: 6,
      bright_white: 7,
      gray: 0,
      grey: 0,
    }.freeze

    extend self

    def parse(color, foreground:)
      base = foreground ? 30 : 40
      hi_base = foreground ? 90 : 100

      code = case color
      when Symbol
        parse_symbol(color, base, hi_base)
      when Integer
        parse_integer(color, base, hi_base)
      when Array
        parse_array(color, base)
      when String
        parse_string(color, base)
      end

      code || []
    end

    private

    def parse_symbol(color, base, hi_base)
      color_code_from_symbol(color, base, BASIC) ||
        color_code_from_symbol(color, hi_base, BRIGHT)
    end

    def color_code_from_symbol(color, base, color_lookup)
      code = color_lookup[color]

      return if code.nil?

      [base + code]
    end

    def parse_integer(color, base, hi_base)
      return [base + color] if color < 8
      return [hi_base + (color - 8)] if color < 16

      [base + 8, 5, color]
    end

    def parse_array(color, base)
      r, g, b = color

      [base + 8, 2, r || 0, g || 0, b || 0]
    end

    def parse_string(color, base)
      return unless color.match?(/\A#?[0-9a-fA-F]{6}\z/)

      hex = color.delete_prefix("#")
      r = hex[0, 2].to_i(16)
      g = hex[2, 2].to_i(16)
      b = hex[4, 2].to_i(16)
      [base + 8, 2, r, g, b]
    end
  end
end
