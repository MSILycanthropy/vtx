# frozen_string_literal: true

require "test_helper"

class TestTerminal < Minitest::Test
  def setup
    @input = StringIO.new
    @output = StringIO.new
    @term = Vtx::Terminal.new(input: @input, output: @output)
  end

  def test_print_buffers_output
    @term.print("hello")
    assert_equal("", @output.string)
  end

  def test_flush_writes_buffer
    @term.print("hello")
    @term.flush
    assert_equal("hello", @output.string)
  end

  def test_puts_adds_newline
    @term.puts("hello")
    @term.flush
    assert_equal("hello\n", @output.string)
  end

  def test_print_with_style
    @term.print("hello", foreground: :red)
    @term.flush
    assert_equal("\e[31mhello\e[0m", @output.string)
  end

  def test_print_with_style_object
    style = Vtx::Style.new(foreground: :blue, bold: true)
    @term.print("hello", style: style)
    @term.flush
    assert_equal("\e[1;34mhello\e[0m", @output.string)
  end

  def test_print_returns_self
    assert_same(@term, @term.print("hello"))
  end

  def test_chaining
    @term.print("a").print("b").print("c").flush
    assert_equal("abc", @output.string)
  end

  def test_sync_auto_flushes
    @term.sync do
      @term.print("hello")
    end
    assert_includes(@output.string, "hello")
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

  def test_save_restore_cursor
    @term.save_cursor.restore_cursor.flush
    assert_equal("\e7\e8", @output.string)
  end

  def test_with_cursor
    @term.with_cursor do
      @term.move_to(0, 0)
    end
    @term.flush
    assert_equal("\e7\e[1;1H\e8", @output.string)
  end

  def test_clear
    @term.clear.flush
    assert_equal("\e[2J", @output.string)
  end

  def test_clear_line
    @term.clear_line.flush
    assert_equal("\e[2K", @output.string)
  end

  def test_scroll_up
    @term.scroll_up(5).flush
    assert_equal("\e[5S", @output.string)
  end

  def test_scroll_down
    @term.scroll_down(3).flush
    assert_equal("\e[3T", @output.string)
  end

  def test_alternate_screen_state
    refute(@term.alternate_screen?)
    @term.enter_alternate_screen
    assert(@term.alternate_screen?)
    @term.leave_alternate_screen
    refute(@term.alternate_screen?)
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

  def test_mouse_capture_state
    refute(@term.mouse_capture?)
    @term.enable_mouse_capture(mode: :normal)
    assert_equal(:normal, @term.mouse_capture)
    @term.disable_mouse_capture
    refute(@term.mouse_capture?)
  end

  def test_bracketed_paste_state
    refute(@term.bracketed_paste?)
    @term.enable_bracketed_paste
    assert(@term.bracketed_paste?)
    @term.disable_bracketed_paste
    refute(@term.bracketed_paste?)
  end

  def test_focus_events_state
    refute(@term.focus_events?)
    @term.enable_focus_events
    assert(@term.focus_events?)
    @term.disable_focus_events
    refute(@term.focus_events?)
  end

  def test_title
    @term.title("My App").flush
    assert_equal("\e]2;My App\e\\", @output.string)
  end

  def test_bell
    @term.bell.flush
    assert_equal("\a", @output.string)
  end

  def test_hyperlink
    @term.hyperlink("https://example.com", "click").flush
    assert_equal("\e]8;;https://example.com\e\\click\e]8;;\e\\", @output.string)
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
      @term.scoped.alternate_screen.call do
        raise "boom"
      end
    end

    refute(@term.alternate_screen?)
  end
end
