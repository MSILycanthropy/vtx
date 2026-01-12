# frozen_string_literal: true

require "test_helper"

class TestTerminal < Minitest::Test
  def setup
    @input = StringIO.new
    @output = StringIO.new
    @term = Vtx::Terminal.new(input: @input, output: @output)
  end

  def test_write_returns_byte_count
    assert_equal(5, @term.write("hello"))
  end

  def test_write_buffers_output
    @term.write("hello")
    assert_equal("", @output.string)
  end

  def test_print_returns_nil
    assert_nil(@term.print("hello"))
  end

  def test_print_buffers_output
    @term.print("hello")
    assert_equal("", @output.string)
  end

  def test_puts_returns_nil
    assert_nil(@term.puts("hello"))
  end

  def test_puts_adds_newline
    @term.puts("hello")
    @term.flush
    assert_equal("hello\n", @output.string)
  end

  def test_puts_empty_writes_newline
    @term.puts
    @term.flush
    assert_equal("\n", @output.string)
  end

  def test_puts_multiple_args
    @term.puts("a", "b", "c")
    @term.flush
    assert_equal("a\nb\nc\n", @output.string)
  end

  def test_flush_writes_buffer
    @term.print("hello")
    @term.flush
    assert_equal("hello", @output.string)
  end

  def test_flush_returns_self
    assert_same(@term, @term.flush)
  end

  def test_print_with_style
    @term.print("hello", foreground: :red)
    @term.flush
    assert_equal("\e[31mhello\e[0m", @output.string)
  end

  def test_print_with_style_object
    style = Vtx::Style.new(foreground: :blue, bold: true)
    @term.print("hello", style:)
    @term.flush
    assert_equal("\e[1;34mhello\e[0m", @output.string)
  end

  def test_puts_with_style
    @term.puts("hello", foreground: :green)
    @term.flush
    assert_equal("\e[32mhello\e[0m\n", @output.string)
  end

  def test_sync_auto_flushes
    @term.sync { @term.print("hello") }
    assert_equal("hello", @output.string)
  end

  def test_read_delegates_to_input
    @input = StringIO.new("hello")
    @term = Vtx::Terminal.new(input: @input, output: @output)
    assert_equal("hel", @term.read(3))
  end

  def test_readpartial_delegates_to_input
    @input = StringIO.new("hello")
    @term = Vtx::Terminal.new(input: @input, output: @output)
    assert_equal("hello", @term.readpartial(100))
  end

  def test_getc_delegates_to_input
    @input = StringIO.new("abc")
    @term = Vtx::Terminal.new(input: @input, output: @output)
    assert_equal("a", @term.getc)
    assert_equal("b", @term.getc)
  end

  def test_getbyte_delegates_to_input
    @input = StringIO.new("abc")
    @term = Vtx::Terminal.new(input: @input, output: @output)
    assert_equal(97, @term.getbyte)
  end

  def test_move_to
    @term.move_to(5, 10).flush
    assert_equal("\e[6;11H", @output.string)
  end

  def test_move_up
    @term.move_up(3).flush
    assert_equal("\e[3A", @output.string)
  end

  def test_move_down
    @term.move_down(2).flush
    assert_equal("\e[2B", @output.string)
  end

  def test_move_forward
    @term.move_forward(5).flush
    assert_equal("\e[5C", @output.string)
  end

  def test_move_back
    @term.move_back(4).flush
    assert_equal("\e[4D", @output.string)
  end

  def test_move_home
    @term.move_home.flush
    assert_equal("\e[H", @output.string)
  end

  def test_move_to_column
    @term.move_to_column(5).flush
    assert_equal("\e[6G", @output.string)
  end

  def test_move_to_row
    @term.move_to_row(10).flush
    assert_equal("\e[11d", @output.string)
  end

  def test_move_to_next_line
    @term.move_to_next_line(2).flush
    assert_equal("\e[2E", @output.string)
  end

  def test_move_to_prev_line
    @term.move_to_prev_line(3).flush
    assert_equal("\e[3F", @output.string)
  end

  def test_save_restore_cursor
    @term.save_cursor.restore_cursor.flush
    assert_equal("\e[s\e[u", @output.string)
  end

  def test_with_cursor
    @term.with_cursor { @term.move_to(0, 0) }
    @term.flush
    assert_equal("\e[s\e[1;1H\e[u", @output.string)
  end

  def test_clear
    @term.clear.flush
    assert_equal("\e[2J", @output.string)
  end

  def test_clear_below
    @term.clear_below.flush
    assert_equal("\e[0J", @output.string)
  end

  def test_clear_above
    @term.clear_above.flush
    assert_equal("\e[1J", @output.string)
  end

  def test_clear_line
    @term.clear_line.flush
    assert_equal("\e[2K", @output.string)
  end

  def test_clear_line_right
    @term.clear_line_right.flush
    assert_equal("\e[0K", @output.string)
  end

  def test_clear_line_left
    @term.clear_line_left.flush
    assert_equal("\e[1K", @output.string)
  end

  def test_scroll_up
    @term.scroll_up(5).flush
    assert_equal("\e[5S", @output.string)
  end

  def test_scroll_down
    @term.scroll_down(3).flush
    assert_equal("\e[3T", @output.string)
  end

  def test_set_scroll_region
    @term.set_scroll_region(5, 20).flush
    assert_equal("\e[6;21r", @output.string)
  end

  def test_reset_scroll_region
    @term.reset_scroll_region.flush
    assert_equal("\e[r", @output.string)
  end

  def test_insert_lines
    @term.insert_lines(3).flush
    assert_equal("\e[3L", @output.string)
  end

  def test_delete_lines
    @term.delete_lines(2).flush
    assert_equal("\e[2M", @output.string)
  end

  def test_insert_chars
    @term.insert_chars(4).flush
    assert_equal("\e[4@", @output.string)
  end

  def test_delete_chars
    @term.delete_chars(2).flush
    assert_equal("\e[2P", @output.string)
  end

  def test_erase_chars
    @term.erase_chars(5).flush
    assert_equal("\e[5X", @output.string)
  end

  def test_alternate_screen_state
    refute(@term.alternate_screen?)
    @term.enter_alternate_screen
    assert(@term.alternate_screen?)
    @term.leave_alternate_screen
    refute(@term.alternate_screen?)
  end

  def test_alternate_screen_sequences
    @term.enter_alternate_screen.flush
    assert_equal("\e[?1049h", @output.string)
  end

  def test_alternate_screen_idempotent
    @term.enter_alternate_screen.flush
    @output.truncate(0)
    @output.rewind
    @term.enter_alternate_screen.flush
    assert_equal("", @output.string)
  end

  def test_cursor_visible_state
    assert(@term.cursor_visible?)
    @term.hide_cursor
    refute(@term.cursor_visible?)
    @term.show_cursor
    assert(@term.cursor_visible?)
  end

  def test_cursor_visibility_sequences
    @term.hide_cursor.flush
    assert_equal("\e[?25l", @output.string)
  end

  def test_mouse_capture_state
    refute(@term.mouse_capture?)
    @term.enable_mouse_capture(mode: :normal)
    assert_equal(:normal, @term.mouse_capture)
    @term.disable_mouse_capture
    refute(@term.mouse_capture?)
  end

  def test_mouse_capture_modes
    @term.enable_mouse_capture(mode: :normal).flush
    assert_equal("\e[?1000h\e[?1006h", @output.string)

    @output.truncate(0)
    @output.rewind
    @term.disable_mouse_capture.enable_mouse_capture(mode: :button).flush
    assert_includes(@output.string, "\e[?1002h")

    @output.truncate(0)
    @output.rewind
    @term.disable_mouse_capture.enable_mouse_capture(mode: :all).flush
    assert_includes(@output.string, "\e[?1003h")
  end

  def test_bracketed_paste_state
    refute(@term.bracketed_paste?)
    @term.enable_bracketed_paste
    assert(@term.bracketed_paste?)
    @term.disable_bracketed_paste
    refute(@term.bracketed_paste?)
  end

  def test_bracketed_paste_sequences
    @term.enable_bracketed_paste.flush
    assert_equal("\e[?2004h", @output.string)
  end

  def test_focus_events_state
    refute(@term.focus_events?)
    @term.enable_focus_events
    assert(@term.focus_events?)
    @term.disable_focus_events
    refute(@term.focus_events?)
  end

  def test_focus_events_sequences
    @term.enable_focus_events.flush
    assert_equal("\e[?1004h", @output.string)
  end

  def test_title
    @term.title("My App").flush
    assert_equal("\e]2;My App\e\\", @output.string)
  end

  def test_icon_name
    @term.icon_name("app").flush
    assert_equal("\e]1;app\e\\", @output.string)
  end

  def test_bell
    @term.bell.flush
    assert_equal("\a", @output.string)
  end

  def test_hyperlink
    @term.hyperlink("https://example.com", "click").flush
    assert_equal("\e]8;;https://example.com\e\\click\e]8;;\e\\", @output.string)
  end

  def test_hyperlink_with_id
    @term.hyperlink("https://example.com", "click", id: "link1").flush
    assert_equal("\e]8;id=link1;https://example.com\e\\click\e]8;;\e\\", @output.string)
  end

  def test_hyperlink_start_end
    @term.hyperlink_start("https://example.com")
    @term.write("click")
    @term.hyperlink_end
    @term.flush
    assert_equal("\e]8;;https://example.com\e\\click\e]8;;\e\\", @output.string)
  end

  def test_copy_to_clipboard
    @term.copy_to_clipboard("hello").flush
    assert_includes(@output.string, "\e]52;c;")
  end

  def test_notify
    @term.notify("Title", body: "Body").flush
    assert_equal("\e]777;notify;Title;Body\e\\", @output.string)
  end

  def test_tty_returns_false_for_stringio
    refute(@term.tty?)
  end

  def test_size_returns_nil_for_non_tty
    assert_nil(@term.size)
  end

  def test_reset_restores_state
    @term.enter_alternate_screen
    @term.hide_cursor
    @term.enable_mouse_capture
    @term.enable_bracketed_paste
    @term.enable_focus_events

    @term.reset

    refute(@term.alternate_screen?)
    assert(@term.cursor_visible?)
    refute(@term.mouse_capture?)
    refute(@term.bracketed_paste?)
    refute(@term.focus_events?)
  end

  def test_copy_stream_from_terminal
    @input = StringIO.new("hello world")
    @term = Vtx::Terminal.new(input: @input, output: @output)
    dest = StringIO.new

    IO.copy_stream(@term.input, dest)

    assert_equal("hello world", dest.string)
  end

  def test_copy_stream_to_terminal
    src = StringIO.new("hello world")

    IO.copy_stream(src, @term.output)

    assert_equal("hello world", @output.string)
  end

  def test_copy_stream_with_length
    @input = StringIO.new("hello world")
    @term = Vtx::Terminal.new(input: @input, output: @output)
    dest = StringIO.new

    IO.copy_stream(@term.input, dest, 5)

    assert_equal("hello", dest.string)
  end

  def test_close_calls_reset
    @term.enter_alternate_screen
    @term.close
    refute(@term.alternate_screen?)
  end

  def test_scoped_restores_on_exit
    @term.scoped.alternate_screen.hidden_cursor.call do |t|
      assert(t.alternate_screen?)
      refute(t.cursor_visible?)
    end

    refute(@term.alternate_screen?)
    assert(@term.cursor_visible?)
  end

  def test_scoped_restores_on_exception
    assert_raises(RuntimeError) do
      @term.scoped.alternate_screen.call { raise "boom" }
    end

    refute(@term.alternate_screen?)
  end
end
