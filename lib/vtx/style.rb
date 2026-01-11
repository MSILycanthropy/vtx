# frozen_string_literal: true

module Vtx
  # Reusable style objects for text formatting.
  #
  # @example Creating styles
  #   style = Vtx::Style.new(foreground: :red, bold: true)
  #   style = Vtx::Style.new.foreground(:red).bold
  #
  # @example Usage
  #   term.print("error", style: style)
  #   styled_str = style.wrap("error")  # => "\e[31;1merror\e[0m"
  #
  # @example Merging
  #   base = Vtx::Style.new(foreground: :white, bold: true)
  #   alert = base.merge(foreground: :red)  # bold: true, foreground: :red
  #
  class Style
    ATTRIBUTES = [:foreground, :background, :bold, :dim, :italic, :underline, :blink, :reverse, :hidden, :strikethrough].freeze

    def initialize(foreground: nil, background: nil, bold: false, dim: false, italic: false,
      underline: false, blink: false, reverse: false, hidden: false, strikethrough: false)
      @foreground = foreground
      @background = background
      @bold = bold
      @dim = dim
      @italic = italic
      @underline = underline
      @blink = blink
      @reverse = reverse
      @hidden = hidden
      @strikethrough = strikethrough
    end

    attr_reader(*ATTRIBUTES)

    def foreground(color)
      @foreground = color

      self
    end

    def background(color)
      @background = color

      self
    end

    def bold(value = true)
      @bold = value

      self
    end

    def dim(value = true)
      @dim = value

      self
    end

    def italic(value = true)
      @italic = value

      self
    end

    def underline(value = true)
      @underline = value

      self
    end

    def blink(value = true)
      @blink = value

      self
    end

    def reverse(value = true)
      @reverse = value

      self
    end

    def hidden(value = true)
      @hidden = value

      self
    end

    def strikethrough(value = true)
      @strikethrough = value

      self
    end

    def merge(**options)
      Style.new(
        foreground: options.fetch(:foreground, @foreground),
        background: options.fetch(:background, @background),
        bold: options.fetch(:bold, @bold),
        dim: options.fetch(:dim, @dim),
        italic: options.fetch(:italic, @italic),
        underline: options.fetch(:underline, @underline),
        blink: options.fetch(:blink, @blink),
        reverse: options.fetch(:reverse, @reverse),
        hidden: options.fetch(:hidden, @hidden),
        strikethrough: options.fetch(:strikethrough, @strikethrough),
      )
    end

    def dup
      Style.new(
        foreground: @foreground,
        background: @background,
        bold: @bold,
        dim: @dim,
        italic: @italic,
        underline: @underline,
        blink: @blink,
        reverse: @reverse,
        hidden: @hidden,
        strikethrough: @strikethrough,
      )
    end

    def wrap(str)
      "#{self}#{str}\e[0m"
    end

    def to_s
      codes = []

      codes << 1 if @bold
      codes << 2 if @dim
      codes << 3 if @italic
      codes << 4 if @underline
      codes << 5 if @blink
      codes << 7 if @reverse
      codes << 8 if @hidden
      codes << 9 if @strikethrough

      codes.concat(Color.parse(@foreground, foreground: true)) if @foreground
      codes.concat(Color.parse(@background, foreground: false)) if @background

      return "" if codes.empty?

      "\e[#{codes.join(";")}m"
    end

    def empty?
      !@bold && !@dim && !@italic && !@underline && !@blink &&
        !@reverse && !@hidden && !@strikethrough && @foreground.nil? && @background.nil?
    end

    def ==(other)
      return false unless other.is_a?(Style)

      ATTRIBUTES.all? { |attr| public_send(attr) == other.public_send(attr) }
    end
    alias_method :eql?, :==

    def hash
      ATTRIBUTES.map { |attr| public_send(attr) }.hash
    end
  end
end
