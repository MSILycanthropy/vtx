# frozen_string_literal: true

# A little showcase to confirm that Vtx::Terminal works

require "bundler/setup"
require "vtx"

class Showcase
  def initialize
    @term = Vtx::Terminal.new
    @examples = []
  end

  def example(name, &block)
    @examples << { name: name, block: block }
  end

  def run
    selected = select_examples
    return if selected.empty?

    @term.scoped
      .raw_mode
      .alternate_screen
      .hidden_cursor
      .run do
        selected.each do |ex|
          @term.clear
          @term.move_to(0, 0)
          @term.puts(ex[:name], foreground: :cyan, bold: true)
          @term.puts("─" * 50, foreground: :bright_black)
          @term.puts

          ex[:block].call(@term)

          @term.puts
          @term.puts("[SPACE] next  [q] quit", foreground: :bright_black)
          @term.flush

          break unless wait_for_next
        end
      end
  end

  def select_examples
    @selected = Array.new(@examples.length, false)
    @cursor = 0

    @term.scoped
      .raw_mode
      .alternate_screen
      .hidden_cursor
      .run do
        loop do
          render_selection

          event = @term.read_event
          case event
          in Vtx::Key(code: :char, char: "q") | Vtx::Key(code: :escape)
            return []
          in Vtx::Key(code: :char, char: "a")
            all_selected = @selected.all?
            @selected = Array.new(@examples.length, !all_selected)
          in Vtx::Key(code: :enter)
            selected_examples = @examples.each_with_index.filter_map { |ex, i| ex if @selected[i] }
            return selected_examples.empty? ? @examples : selected_examples
          in Vtx::Key(code: :char, char: " ")
            @selected[@cursor] = !@selected[@cursor]
          in Vtx::Key(code: :up) | Vtx::Key(code: :char, char: "k")
            @cursor = (@cursor - 1) % @examples.length
          in Vtx::Key(code: :down) | Vtx::Key(code: :char, char: "j")
            @cursor = (@cursor + 1) % @examples.length
          else
            next
          end
        end
      end
  end

  def render_selection
    @term.sync do
      @term.move_to(0, 0)
      @term.puts("VTX Feature Showcase", foreground: :cyan, bold: true)
      @term.puts("─" * 30, foreground: :bright_black)
      @term.puts
      @term.puts("Select examples to run, then press ENTER.", foreground: :white)
      @term.puts("SPACE: toggle  a: all  ENTER: run  q: quit", foreground: :bright_black)
      @term.puts

      @examples.each_with_index do |ex, i|
        @term.move_to(i + 6, 0)
        @term.clear_line

        checkbox = @selected[i] ? "[✓]" : "[ ]"
        checkbox_color = @selected[i] ? :green : :bright_black

        if i == @cursor
          @term.print(" ▸ ", foreground: :yellow, bold: true)
          @term.print(checkbox, foreground: checkbox_color)
          @term.print(" #{ex[:name]}", foreground: :white, bold: true)
        else
          @term.print("   ", foreground: :bright_black)
          @term.print(checkbox, foreground: checkbox_color)
          @term.print(" #{ex[:name]}", foreground: :bright_black)
        end
      end

      count = @selected.count(true)
      @term.move_to(@examples.length + 7, 0)
      @term.clear_line
      @term.print("#{count} of #{@examples.length} selected", foreground: :bright_black)
    end
  end

  def wait_for_next
    loop do
      event = @term.read_event
      case event
      in Vtx::Key(code: :char, char: " ") | Vtx::Key(code: :enter)
        return true
      in Vtx::Key(code: :char, char: "q") | Vtx::Key(code: :escape)
        return false
      else
        next
      end
    end
  end
end

showcase = Showcase.new

showcase.example("Basic Colors") do |t|
  t.puts("Foreground colors (8 standard + 8 bright):")
  t.puts

  [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white].each do |color|
    t.print("████ ", foreground: color)
  end
  t.puts

  [
    :bright_black,
    :bright_red,
    :bright_green,
    :bright_yellow,
    :bright_blue,
    :bright_magenta,
    :bright_cyan,
    :bright_white,
  ].each do |color|
    t.print("████ ", foreground: color)
  end
  t.puts
end

showcase.example("Background Colors") do |t|
  t.puts("Background colors:")
  t.puts

  [:red, :green, :yellow, :blue, :magenta, :cyan, :white].each do |color|
    t.print("    ", background: color)
  end
  t.puts
end

showcase.example("256 Color Palette") do |t|
  t.puts("256 color mode (system colors, color cube, grayscale):")
  t.puts

  (0..15).each { |c| t.print("  ", background: c) }
  t.puts

  (16..231).each_slice(36) do |row|
    row.each { |c| t.print(" ", background: c) }
    t.puts
  end

  (232..255).each { |c| t.print(" ", background: c) }
  t.puts
end

showcase.example("RGB True Color") do |t|
  t.puts("24-bit RGB gradients:")
  t.puts

  24.times { |i| t.print(" ", background: [(i * 10.6).to_i, 0, 0]) }
  t.puts
  24.times { |i| t.print(" ", background: [0, (i * 10.6).to_i, 0]) }
  t.puts
  24.times { |i| t.print(" ", background: [0, 0, (i * 10.6).to_i]) }
  t.puts
end

showcase.example("Hex Colors") do |t|
  t.puts("Hex color notation:")
  t.puts

  ["#ff0000", "#ff7f00", "#ffff00", "#00ff00", "#0000ff", "#4b0082", "#9400d3"].each do |hex|
    t.print("  #{hex}  ", background: hex, foreground: :white, bold: true)
  end
  t.puts
end

showcase.example("Text Styles") do |t|
  t.puts("Available text attributes:")
  t.puts

  t.puts("  Normal text")
  t.puts("  Bold text", bold: true)
  t.puts("  Dim text", dim: true)
  t.puts("  Italic text", italic: true)
  t.puts("  Underline text", underline: true)
  t.puts("  Strikethrough text", strikethrough: true)
  t.puts("  Reversed text", reverse: true)
end

showcase.example("Combined Styles") do |t|
  t.puts("Multiple styles can be combined:")
  t.puts

  t.puts("  Bold + Red", bold: true, foreground: :red)
  t.puts("  Italic + Blue on Yellow", italic: true, foreground: :blue, background: :yellow)
  t.puts("  Underline + Bold + Cyan", underline: true, bold: true, foreground: :cyan)
end

showcase.example("Cursor Movement") do |t|
  base_row = 4

  t.puts("Absolute cursor positioning with move_to(row, col):")
  t.puts("1....5....0....5....")
  t.puts("2")
  t.puts("3")
  t.puts("4")
  t.puts("5")

  t.move_to(base_row + 2, 10)
  t.print("X", foreground: :red, bold: true)

  t.move_to(base_row + 4, 5)
  t.print("Y", foreground: :green, bold: true)

  t.move_to(base_row + 5, 0)
  t.puts
  t.puts("X should appear at row 3, col 10")
  t.puts("Y should appear at row 5, col 5")
end

showcase.example("Relative Cursor Movement") do |t|
  base_row = 4

  t.puts("Relative movement: move_up, move_down, move_forward, move_back")
  t.puts("1....5....0....5....")
  t.puts("2")
  t.puts("3")
  t.puts("4")
  t.puts("5")

  t.move_to(base_row + 3, 5)
  t.print("A", foreground: :red, bold: true)

  t.move_forward(5)
  t.print("B", foreground: :green, bold: true)

  t.move_down(1)
  t.print("C", foreground: :blue, bold: true)

  t.move_back(8)
  t.print("D", foreground: :yellow, bold: true)

  t.move_up(2)
  t.print("E", foreground: :magenta, bold: true)

  t.move_to(base_row + 8, 0)
  t.puts("Path: A → forward 5 → B → down 1 → C → back 8 → D → up 2 → E")
end

showcase.example("Cursor Styles") do |t|
  t.show_cursor
  t.flush

  t.puts("Cycling through cursor styles (2 sec each):")
  t.puts

  [:block, :underline, :bar].each do |style|
    [true, false].each do |blink|
      t.cursor_style(style, blink: blink)
      t.move_to(4, 0)
      t.clear_line
      t.print("  → #{style}, blink: #{blink}", foreground: :yellow)
      t.flush
      sleep 2
    end
  end

  t.reset_cursor_style
  t.hide_cursor
  t.move_to(6, 0)
  t.puts
  t.puts("Cursor should have changed 6 times.")
end

showcase.example("Clear Line") do |t|
  t.puts("clear_line replaces entire line content:")
  t.puts

  t.puts("  This line stays")
  t.puts("  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
  t.move_up(1)
  t.clear_line
  t.puts("  This replaced the X's")
  t.puts("  This line also stays")
end

showcase.example("Clear Line Partial") do |t|
  t.puts("clear_line_right and clear_line_left:")
  t.puts

  t.puts("  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
  t.move_up(1)
  t.move_forward(17)
  t.clear_line_right
  t.puts

  t.puts("  BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB")
  t.move_up(1)
  t.move_forward(17)
  t.clear_line_left
  t.puts
  t.puts
  t.puts("  First line: A's on left only")
  t.puts("  Second line: B's on right only")
end

showcase.example("Scroll Regions") do |t|
  t.puts("set_scroll_region confines scrolling to a region:")
  t.puts("=" * 40)

  t.move_to(12, 0)
  t.puts("=" * 40)
  t.puts("Footer stays fixed")
  t.puts
  t.puts("Watch content scroll between the lines.")

  t.set_scroll_region(5, 11)
  t.move_to(5, 0)
  t.flush

  15.times do |i|
    t.puts("  Scrolling line #{i + 1}")
    t.flush
    sleep 0.15
  end

  t.reset_scroll_region
  t.flush

  t.move_to(15, 0)
end

showcase.example("Synchronized Output") do |t|
  t.puts("sync { } batches output to prevent flicker:")
  t.puts

  30.times do |frame|
    t.sync do
      8.times do |row|
        t.move_to(4 + row, 0)
        40.times do |col|
          color = (row + col + frame).even? ? :blue : :yellow
          t.print(" ", background: color)
        end
      end
    end
    sleep 0.05
  end

  t.move_to(13, 0)
  t.puts("Animation should have been smooth, no flicker.")
end

showcase.example("Keyboard Input") do |t|
  t.puts("Type keys to see their event data. Press ESC to finish.")
  t.puts
  t.puts("Last key:")
  t.flush

  loop do
    event = t.read_event
    case event
    in Vtx::Key(code: :escape)
      break
    in Vtx::Key => key
      t.move_to(5, 9)
      t.clear_line_right

      parts = ["code: #{key.code.inspect}"]
      parts << "char: #{key.char.inspect}" if key.char
      parts << "ctrl" if key.ctrl
      parts << "alt" if key.alt
      parts << "shift" if key.shift

      t.print("  #{parts.join(", ")}", foreground: :green)
      t.flush
    else
      next
    end
  end
end

showcase.example("Mouse Clicks") do |t|
  t.puts("Click inside the box. Press SPACE when done.")
  t.puts

  t.puts("  ┌────────────────────────────┐")
  5.times { t.puts("  │                            │") }
  t.puts("  └────────────────────────────┘")
  t.puts
  t.puts("  Last click:")
  t.flush

  t.enable_mouse_capture
  t.flush

  loop do
    event = t.read_event
    case event
    in Vtx::Mouse(kind: :press, button: :left, row:, col:)
      t.move_to(13, 14)
      t.clear_line_right
      t.print("row: #{row}, col: #{col}", foreground: :green)
      t.flush
    in Vtx::Key(code: :char, char: " ")
      break
    else
      next
    end
  end

  t.disable_mouse_capture
  t.flush
end

showcase.example("Mouse Drag") do |t|
  t.puts("Drag with left mouse button to draw. Press SPACE when done.")
  t.puts
  t.flush

  t.enable_mouse_capture(mode: :all)
  t.flush

  drawing = false
  loop do
    event = t.read_event
    case event
    in Vtx::Mouse(kind: :press, button: :left)
      drawing = true
    in Vtx::Mouse(kind: :release, button: :left)
      drawing = false
    in Vtx::Mouse(kind: :drag, row:, col:) if drawing
      next if row < 3

      t.move_to(row, col)
      t.print("●", foreground: :cyan)
      t.flush
    in Vtx::Key(code: :char, char: " ")
      break
    else
      next
    end
  end

  t.disable_mouse_capture
  t.flush
end

showcase.example("Bracketed Paste") do |t|
  t.puts("Paste text. Press SPACE when done.")
  t.puts
  t.puts("Pasted:")
  t.flush

  t.enable_bracketed_paste
  t.flush

  loop do
    event = t.read_event
    case event
    in Vtx::Paste(content:)
      t.move_to(5, 7)
      t.clear_line_right

      preview = content.length > 60 ? "#{content[0, 60]}..." : content
      preview = preview.gsub("\n", "↵")

      t.print(preview.inspect, foreground: :green)
      t.flush
    in Vtx::Key(code: :char, char: " ")
      break
    else
      next
    end
  end

  t.disable_bracketed_paste
  t.flush
end

showcase.example("Focus Events") do |t|
  t.puts("Click outside this window, then back. Press SPACE when done.")
  t.puts
  t.puts("Events:")
  t.flush

  t.enable_focus_events
  t.flush

  count = 0
  loop do
    event = t.read_event
    case event
    in Vtx::Focus(focused:)
      count += 1
      status = focused ? "focused" : "blurred"
      color = focused ? :green : :yellow
      t.move_to(4 + count, 8)
      t.print("  #{count}. Window #{status}", foreground: color)
      t.flush
    in Vtx::Key(code: :char, char: " ")
      break
    else
      next
    end
  end

  t.disable_focus_events
  t.flush
end

showcase.example("Hyperlinks") do |t|
  t.puts("OSC 8 hyperlinks (Cmd/Ctrl+click to open):")
  t.puts

  t.print("  ")
  t.hyperlink("https://github.com", "GitHub")
  t.puts

  t.print("  ")
  t.hyperlink("https://google.com", "Google")
  t.puts

  t.print("  ")
  t.hyperlink("https://example.com", "Example (with id)", id: "demo-link")
  t.puts
  t.puts
  t.puts("Not all terminals support clickable links.")
end

showcase.example("Clipboard") do |t|
  text = "Hello from VTX! #{Time.now.strftime("%H:%M:%S")}"

  t.puts("OSC 52 clipboard copy:")
  t.puts
  t.puts("  Copying: #{text.inspect}")
  t.puts

  t.copy_to_clipboard(text)
  t.flush

  t.puts("Paste somewhere to verify. Not all terminals support OSC 52.")
end

showcase.example("Window Title") do |t|
  t.puts("Changing window/tab title:")
  t.puts

  titles = ["VTX Demo 1", "VTX Demo 2", "🚀 VTX!", "VTX"]
  titles.each do |title|
    t.title(title)
    t.flush
    t.puts("  Set title to: #{title}")
    sleep 1.5
  end
  t.puts
  t.puts("Watch your terminal's title bar or tab.")
end

showcase.run
