# frozen_string_literal: true

require "test_helper"

class TestEventParser < Minitest::Test
  def setup
    @parser = Vtx::EventParser.new
  end

  def test_simple_characters
    events = @parser.feed("abc")
    assert_equal(3, events.length)
    assert_equal(Vtx::Key.new(code: :char, char: "a"), events[0])
    assert_equal(Vtx::Key.new(code: :char, char: "b"), events[1])
    assert_equal(Vtx::Key.new(code: :char, char: "c"), events[2])
  end

  def test_enter
    events = @parser.feed("\r")
    assert_equal([Vtx::Key.new(code: :enter)], events)
  end

  def test_tab
    events = @parser.feed("\t")
    assert_equal([Vtx::Key.new(code: :tab)], events)
  end

  def test_backspace
    events = @parser.feed("\x7F")
    assert_equal([Vtx::Key.new(code: :backspace)], events)
  end

  def test_ctrl_c
    events = @parser.feed("\x03")
    assert_equal([Vtx::Key.new(code: :char, char: "c", ctrl: true)], events)
  end

  def test_ctrl_a
    events = @parser.feed("\x01")
    assert_equal([Vtx::Key.new(code: :char, char: "a", ctrl: true)], events)
  end

  def test_ctrl_z
    events = @parser.feed("\x1A")
    assert_equal([Vtx::Key.new(code: :char, char: "z", ctrl: true)], events)
  end

  def test_escape_pending
    events = @parser.feed("\e")
    assert_equal([], events)
    assert(@parser.pending?)
  end

  def test_escape_flush
    @parser.feed("\e")
    events = @parser.flush
    assert_equal([Vtx::Key.new(code: :escape)], events)
    refute(@parser.pending?)
  end

  def test_alt_a
    events = @parser.feed("\ea")
    assert_equal([Vtx::Key.new(code: :char, char: "a", alt: true)], events)
  end

  def test_arrow_up
    events = @parser.feed("\e[A")
    assert_equal([Vtx::Key.new(code: :up)], events)
  end

  def test_arrow_down
    events = @parser.feed("\e[B")
    assert_equal([Vtx::Key.new(code: :down)], events)
  end

  def test_arrow_right
    events = @parser.feed("\e[C")
    assert_equal([Vtx::Key.new(code: :right)], events)
  end

  def test_arrow_left
    events = @parser.feed("\e[D")
    assert_equal([Vtx::Key.new(code: :left)], events)
  end

  def test_home
    events = @parser.feed("\e[H")
    assert_equal([Vtx::Key.new(code: :home)], events)
  end

  def test_end
    events = @parser.feed("\e[F")
    assert_equal([Vtx::Key.new(code: :end)], events)
  end

  def test_home_tilde
    events = @parser.feed("\e[1~")
    assert_equal([Vtx::Key.new(code: :home)], events)
  end

  def test_insert
    events = @parser.feed("\e[2~")
    assert_equal([Vtx::Key.new(code: :insert)], events)
  end

  def test_delete
    events = @parser.feed("\e[3~")
    assert_equal([Vtx::Key.new(code: :delete)], events)
  end

  def test_end_tilde
    events = @parser.feed("\e[4~")
    assert_equal([Vtx::Key.new(code: :end)], events)
  end

  def test_page_up
    events = @parser.feed("\e[5~")
    assert_equal([Vtx::Key.new(code: :page_up)], events)
  end

  def test_page_down
    events = @parser.feed("\e[6~")
    assert_equal([Vtx::Key.new(code: :page_down)], events)
  end

  def test_f1_ss3
    events = @parser.feed("\eOP")
    assert_equal([Vtx::Key.new(code: :f1)], events)
  end

  def test_f2_ss3
    events = @parser.feed("\eOQ")
    assert_equal([Vtx::Key.new(code: :f2)], events)
  end

  def test_f3_ss3
    events = @parser.feed("\eOR")
    assert_equal([Vtx::Key.new(code: :f3)], events)
  end

  def test_f4_ss3
    events = @parser.feed("\eOS")
    assert_equal([Vtx::Key.new(code: :f4)], events)
  end

  def test_f5
    events = @parser.feed("\e[15~")
    assert_equal([Vtx::Key.new(code: :f5)], events)
  end

  def test_f6
    events = @parser.feed("\e[17~")
    assert_equal([Vtx::Key.new(code: :f6)], events)
  end

  def test_f12
    events = @parser.feed("\e[24~")
    assert_equal([Vtx::Key.new(code: :f12)], events)
  end

  def test_shift_tab
    events = @parser.feed("\e[Z")
    assert_equal([Vtx::Key.new(code: :tab, shift: true)], events)
  end

  def test_shift_arrow_up
    events = @parser.feed("\e[1;2A")
    assert_equal([Vtx::Key.new(code: :up, shift: true)], events)
  end

  def test_ctrl_arrow_up
    events = @parser.feed("\e[1;5A")
    assert_equal([Vtx::Key.new(code: :up, ctrl: true)], events)
  end

  def test_alt_arrow_up
    events = @parser.feed("\e[1;3A")
    assert_equal([Vtx::Key.new(code: :up, alt: true)], events)
  end

  def test_ctrl_shift_arrow_up
    events = @parser.feed("\e[1;6A")
    assert_equal([Vtx::Key.new(code: :up, ctrl: true, shift: true)], events)
  end

  def test_focus_in
    events = @parser.feed("\e[I")
    assert_equal([Vtx::Focus.new(focused: true)], events)
  end

  def test_focus_out
    events = @parser.feed("\e[O")
    assert_equal([Vtx::Focus.new(focused: false)], events)
  end

  def test_mouse_press_left
    events = @parser.feed("\e[<0;10;20M")
    assert_equal(1, events.length)
    event = events.first
    assert_instance_of(Vtx::Mouse, event)
    assert_equal(:press, event.kind)
    assert_equal(:left, event.button)
    assert_equal(19, event.row)
    assert_equal(9, event.col)
  end

  def test_mouse_release_left
    events = @parser.feed("\e[<0;10;20m")
    assert_equal(1, events.length)
    event = events.first
    assert_equal(:release, event.kind)
    assert_equal(:left, event.button)
  end

  def test_mouse_middle_button
    events = @parser.feed("\e[<1;10;20M")
    assert_equal(:middle, events.first.button)
  end

  def test_mouse_right_button
    events = @parser.feed("\e[<2;10;20M")
    assert_equal(:right, events.first.button)
  end

  def test_mouse_scroll_up
    events = @parser.feed("\e[<64;10;20M")
    assert_equal(1, events.length)
    event = events.first
    assert_equal(:scroll_up, event.kind)
  end

  def test_mouse_scroll_down
    events = @parser.feed("\e[<65;10;20M")
    assert_equal(1, events.length)
    event = events.first
    assert_equal(:scroll_down, event.kind)
  end

  def test_mouse_drag
    events = @parser.feed("\e[<32;10;20M")
    assert_equal(:drag, events.first.kind)
  end

  def test_mouse_with_shift
    events = @parser.feed("\e[<4;10;20M")
    event = events.first
    assert(event.shift)
    refute(event.ctrl)
    refute(event.alt)
  end

  def test_mouse_with_alt
    events = @parser.feed("\e[<8;10;20M")
    event = events.first
    assert(event.alt)
  end

  def test_mouse_with_ctrl
    events = @parser.feed("\e[<16;10;20M")
    event = events.first
    assert(event.ctrl)
  end

  def test_bracketed_paste
    events = @parser.feed("\e[200~hello world\e[201~")
    assert_equal(1, events.length)
    assert_equal(Vtx::Paste.new(content: "hello world"), events.first)
  end

  def test_bracketed_paste_with_newlines
    events = @parser.feed("\e[200~line1\nline2\e[201~")
    assert_equal(1, events.length)
    assert_equal("line1\nline2", events.first.content)
  end

  def test_bracketed_paste_with_special_chars
    events = @parser.feed("\e[200~hello\tworld\e[201~")
    assert_equal("hello\tworld", events.first.content)
  end

  def test_utf8_single_char
    events = @parser.feed("é")
    assert_equal(1, events.length)
    assert_equal(Vtx::Key.new(code: :char, char: "é"), events.first)
  end

  def test_utf8_emoji
    events = @parser.feed("🎉")
    assert_equal(1, events.length)
    assert_equal(Vtx::Key.new(code: :char, char: "🎉"), events.first)
  end

  def test_utf8_multiple
    events = @parser.feed("日本語")
    assert_equal(3, events.length)
    assert_equal("日", events[0].char)
    assert_equal("本", events[1].char)
    assert_equal("語", events[2].char)
  end

  def test_mixed_sequence
    events = @parser.feed("a\e[Ab")
    assert_equal(3, events.length)
    assert_equal(Vtx::Key.new(code: :char, char: "a"), events[0])
    assert_equal(Vtx::Key.new(code: :up), events[1])
    assert_equal(Vtx::Key.new(code: :char, char: "b"), events[2])
  end

  def test_pattern_matching_key
    event = Vtx::Key.new(code: :char, char: "q", ctrl: true)

    result = case event
    in Vtx::Key(code: :char, char: "q", ctrl: true)
      :quit
    else
      :other
    end

    assert_equal(:quit, result)
  end

  def test_pattern_matching_mouse
    event = Vtx::Mouse.new(kind: :press, button: :left, row: 10, col: 20)

    result = case event
    in Vtx::Mouse(kind: :press, button: :left, row:, col:)
      [row, col]
    else
      :other
    end

    assert_equal([10, 20], result)
  end

  def test_pattern_matching_focus
    event = Vtx::Focus.new(focused: true)

    result = case event
    in Vtx::Focus(focused: true)
      :focused
    in Vtx::Focus(focused: false)
      :unfocused
    end

    assert_equal(:focused, result)
  end

  def test_key_modified?
    refute(Vtx::Key.new(code: :char, char: "a").modified?)
    assert(Vtx::Key.new(code: :char, char: "a", ctrl: true).modified?)
    assert(Vtx::Key.new(code: :char, char: "a", alt: true).modified?)
    assert(Vtx::Key.new(code: :char, char: "a", shift: true).modified?)
  end

  def test_key_modifiers
    event = Vtx::Key.new(code: :char, char: "a", ctrl: true, shift: true)
    assert_equal([:ctrl, :shift], event.modifiers)
  end

  def test_mouse_modified?
    refute(Vtx::Mouse.new(kind: :press, button: :left, row: 0, col: 0).modified?)
    assert(Vtx::Mouse.new(kind: :press, button: :left, row: 0, col: 0, ctrl: true).modified?)
  end

  def test_focus_focused?
    assert(Vtx::Focus.new(focused: true).focused?)
    refute(Vtx::Focus.new(focused: false).focused?)
  end
end
