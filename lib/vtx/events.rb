# frozen_string_literal: true

module Vtx
  Key = Data.define(:code, :char, :ctrl, :alt, :shift) do
    def initialize(code:, char: nil, ctrl: false, alt: false, shift: false)
      super
    end

    def modified? = ctrl || alt || shift

    def modifiers
      mods = []
      mods << :ctrl if ctrl
      mods << :alt if alt
      mods << :shift if shift
      mods
    end

    def inspect
      parts = ["code: #{code.inspect}"]
      parts << "char: #{char.inspect}" if char
      parts << "ctrl: true" if ctrl
      parts << "alt: true" if alt
      parts << "shift: true" if shift
      "Key(#{parts.join(", ")})"
    end
  end

  Mouse = Data.define(:kind, :button, :row, :col, :ctrl, :alt, :shift) do
    def initialize(kind:, button:, row:, col:, ctrl: false, alt: false, shift: false)
      super
    end

    def modified? = ctrl || alt || shift

    def modifiers
      mods = []
      mods << :ctrl if ctrl
      mods << :alt if alt
      mods << :shift if shift
      mods
    end

    def inspect
      "Mouse(kind: #{kind.inspect}, button: #{button.inspect}, row: #{row}, col: #{col})"
    end
  end

  Paste = Data.define(:content) do
    def inspect
      "Paste(content: #{content.inspect})"
    end
  end

  Focus = Data.define(:focused) do
    def focused? = focused

    def inspect
      "Focus(focused: #{focused})"
    end
  end

  Resize = Data.define(:rows, :cols) do
    def inspect
      "Resize(rows: #{rows}, cols: #{cols})"
    end
  end
end
