# frozen_string_literal: true

require "test_helper"

class TestEventParserEdgeCases < Minitest::Test
  def setup
    @parser = Vtx::EventParser.new
  end

  def test_chunked_csi_arrow_key
    events = @parser.feed("\e")
    assert_empty(events)
    assert(@parser.pending?)

    events = @parser.feed("[A")
    assert_equal(1, events.size)
    assert_equal(:up, events.first.code)
  end

  def test_chunked_csi_split_mid_sequence
    events = @parser.feed("\e[")
    assert_empty(events)

    events = @parser.feed("A")
    assert_equal(1, events.size)
    assert_equal(:up, events.first.code)
  end

  def test_chunked_ss3_f1
    events = @parser.feed("\eO")
    assert_empty(events)
    assert(@parser.pending?)

    events = @parser.feed("P")
    assert_equal(1, events.size)
    assert_equal(:f1, events.first.code)
  end

  def test_chunked_ss3_split_at_esc
    events = @parser.feed("\e")
    assert_empty(events)
    assert(@parser.pending?)

    events = @parser.feed("OP")
    assert_equal(1, events.size)
    assert_equal(:f1, events.first.code)
  end

  def test_chunked_tilde_sequence
    events = @parser.feed("\e[15")
    assert_empty(events)

    events = @parser.feed("~")
    assert_equal(1, events.size)
    assert_equal(:f5, events.first.code)
  end

  def test_shift_up_arrow
    events = @parser.feed("\e[1;2A")
    assert_equal(1, events.size)
    event = events.first
    assert_equal(:up, event.code)
    assert(event.shift)
    refute(event.ctrl)
    refute(event.alt)
  end

  def test_alt_down_arrow
    events = @parser.feed("\e[1;3B")
    assert_equal(1, events.size)
    event = events.first
    assert_equal(:down, event.code)
    assert(event.alt)
    refute(event.ctrl)
    refute(event.shift)
  end

  def test_ctrl_right_arrow
    events = @parser.feed("\e[1;5C")
    assert_equal(1, events.size)
    event = events.first
    assert_equal(:right, event.code)
    assert(event.ctrl)
    refute(event.alt)
    refute(event.shift)
  end

  def test_ctrl_shift_left_arrow
    events = @parser.feed("\e[1;6D")
    assert_equal(1, events.size)
    event = events.first
    assert_equal(:left, event.code)
    assert(event.ctrl)
    assert(event.shift)
    refute(event.alt)
  end

  def test_ctrl_alt_up_arrow
    events = @parser.feed("\e[1;7A")
    assert_equal(1, events.size)
    event = events.first
    assert_equal(:up, event.code)
    assert(event.ctrl)
    assert(event.alt)
    refute(event.shift)
  end

  def test_ctrl_alt_shift_down_arrow
    events = @parser.feed("\e[1;8B")
    assert_equal(1, events.size)
    event = events.first
    assert_equal(:down, event.code)
    assert(event.ctrl)
    assert(event.alt)
    assert(event.shift)
  end

  def test_shift_f5
    events = @parser.feed("\e[15;2~")
    assert_equal(1, events.size)
    event = events.first
    assert_equal(:f5, event.code)
    assert(event.shift)
  end

  def test_ctrl_delete
    events = @parser.feed("\e[3;5~")
    assert_equal(1, events.size)
    event = events.first
    assert_equal(:delete, event.code)
    assert(event.ctrl)
  end

  def test_mouse_middle_button
    events = @parser.feed("\e[<1;10;20M")
    assert_equal(1, events.size)
    event = events.first
    assert_kind_of(Vtx::Mouse, event)
    assert_equal(:press, event.kind)
    assert_equal(:middle, event.button)
  end

  def test_mouse_right_button
    events = @parser.feed("\e[<2;10;20M")
    assert_equal(1, events.size)
    event = events.first
    assert_equal(:press, event.kind)
    assert_equal(:right, event.button)
  end

  def test_mouse_with_shift
    events = @parser.feed("\e[<4;10;20M")
    assert_equal(1, events.size)
    event = events.first
    assert(event.shift)
    refute(event.alt)
    refute(event.ctrl)
  end

  def test_mouse_with_alt
    events = @parser.feed("\e[<8;10;20M")
    assert_equal(1, events.size)
    event = events.first
    assert(event.alt)
    refute(event.shift)
    refute(event.ctrl)
  end

  def test_mouse_with_ctrl
    events = @parser.feed("\e[<16;10;20M")
    assert_equal(1, events.size)
    event = events.first
    assert(event.ctrl)
    refute(event.shift)
    refute(event.alt)
  end

  def test_mouse_with_all_modifiers
    events = @parser.feed("\e[<28;10;20M")
    assert_equal(1, events.size)
    event = events.first
    assert(event.shift)
    assert(event.alt)
    assert(event.ctrl)
  end

  def test_mouse_large_coordinates
    events = @parser.feed("\e[<0;500;300M")
    assert_equal(1, events.size)
    event = events.first
    assert_equal(499, event.col)
    assert_equal(299, event.row)
  end

  def test_mouse_drag
    events = @parser.feed("\e[<32;10;20M")
    assert_equal(1, events.size)
    event = events.first
    assert_equal(:drag, event.kind)
    assert_equal(:left, event.button)
  end

  def test_mouse_move
    events = @parser.feed("\e[<35;10;20m")
    assert_equal(1, events.size)
    event = events.first
    assert_equal(:move, event.kind)
  end

  def test_mouse_scroll_up
    events = @parser.feed("\e[<64;10;20M")
    assert_equal(1, events.size)
    event = events.first
    assert_equal(:scroll_up, event.kind)
  end

  def test_mouse_scroll_down
    events = @parser.feed("\e[<65;10;20M")
    assert_equal(1, events.size)
    event = events.first
    assert_equal(:scroll_down, event.kind)
  end

  def test_paste_containing_escape_sequences
    events = @parser.feed("\e[200~hello\e[Aworld\e[201~")
    assert_equal(1, events.size)
    event = events.first
    assert_kind_of(Vtx::Paste, event)
    assert_equal("hello\e[Aworld", event.content)
  end

  def test_paste_containing_newlines
    events = @parser.feed("\e[200~line1\nline2\rline3\e[201~")
    assert_equal(1, events.size)
    event = events.first
    assert_equal("line1\nline2\rline3", event.content)
  end

  def test_paste_containing_tabs
    events = @parser.feed("\e[200~col1\tcol2\tcol3\e[201~")
    assert_equal(1, events.size)
    event = events.first
    assert_equal("col1\tcol2\tcol3", event.content)
  end

  def test_paste_containing_control_characters
    events = @parser.feed("\e[200~hello\x01\x02\x03world\e[201~")
    assert_equal(1, events.size)
    event = events.first
    assert_equal("hello\x01\x02\x03world", event.content)
  end

  def test_empty_paste
    events = @parser.feed("\e[200~\e[201~")
    assert_equal(1, events.size)
    event = events.first
    assert_kind_of(Vtx::Paste, event)
    assert_equal("", event.content)
  end

  def test_paste_chunked
    events = @parser.feed("\e[200~hello")
    assert_empty(events)

    events = @parser.feed(" world\e[201~")
    assert_equal(1, events.size)
    assert_equal("hello world", events.first.content)
  end

  def test_bare_escape_then_timeout
    events = @parser.feed("\e")
    assert_empty(events)
    assert(@parser.pending?)

    events = @parser.flush
    assert_equal(1, events.size)
    assert_equal(:escape, events.first.code)
  end

  def test_escape_followed_by_printable_is_alt
    events = @parser.feed("\ea")
    assert_equal(1, events.size)
    event = events.first
    assert_equal(:char, event.code)
    assert_equal("a", event.char)
    assert(event.alt)
  end

  def test_escape_followed_by_uppercase_is_alt
    events = @parser.feed("\eA")
    assert_equal(1, events.size)
    event = events.first
    assert_equal(:char, event.code)
    assert_equal("A", event.char)
    assert(event.alt)
  end

  def test_escape_followed_by_number_is_alt
    events = @parser.feed("\e5")
    assert_equal(1, events.size)
    event = events.first
    assert_equal(:char, event.code)
    assert_equal("5", event.char)
    assert(event.alt)
  end

  def test_unknown_csi_sequence_ignored
    events = @parser.feed("\e[999z")
    assert_kind_of(Array, events)
  end

  def test_unknown_escape_sequence_ignored
    events = @parser.feed("\e#8")
    assert_kind_of(Array, events)
  end

  def test_multiple_events_in_one_feed
    events = @parser.feed("abc")
    assert_equal(3, events.size)
    assert_equal("a", events[0].char)
    assert_equal("b", events[1].char)
    assert_equal("c", events[2].char)
  end

  def test_mixed_regular_and_escape_sequences
    events = @parser.feed("a\e[Ab")
    assert_equal(3, events.size)
    assert_equal("a", events[0].char)
    assert_equal(:up, events[1].code)
    assert_equal("b", events[2].char)
  end

  def test_focus_in
    events = @parser.feed("\e[I")
    assert_equal(1, events.size)
    event = events.first
    assert_kind_of(Vtx::Focus, event)
    assert(event.focused)
  end

  def test_focus_out
    events = @parser.feed("\e[O")
    assert_equal(1, events.size)
    event = events.first
    assert_kind_of(Vtx::Focus, event)
    refute(event.focused)
  end

  def test_flush_clears_pending_state
    @parser.feed("\e")
    assert(@parser.pending?)

    @parser.flush
    refute(@parser.pending?)
  end

  def test_flush_when_not_pending_returns_empty
    refute(@parser.pending?)
    events = @parser.flush
    assert_empty(events)
  end

  def test_parser_reusable_after_flush
    @parser.feed("\e")
    @parser.flush

    events = @parser.feed("\e[A")
    assert_equal(1, events.size)
    assert_equal(:up, events.first.code)
  end

  def test_flush_is_idempotent
    @parser.feed("\e")
    assert(@parser.pending?)

    events1 = @parser.flush
    assert_equal(1, events1.size)
    refute(@parser.pending?)

    events2 = @parser.flush
    assert_empty(events2)
    refute(@parser.pending?)

    events3 = @parser.flush
    assert_empty(events3)
  end

  def test_long_paste_content
    long_text = "a" * 100_000
    events = @parser.feed("\e[200~#{long_text}\e[201~")
    assert_equal(1, events.size)
    assert_equal(long_text, events.first.content)
  end

  def test_mouse_release
    events = @parser.feed("\e[<0;10;20m")
    assert_equal(1, events.size)
    event = events.first
    assert_equal(:release, event.kind)
    assert_equal(:left, event.button)
  end

  def test_mouse_middle_release
    events = @parser.feed("\e[<1;10;20m")
    assert_equal(1, events.size)
    event = events.first
    assert_equal(:release, event.kind)
    assert_equal(:middle, event.button)
  end

  def test_mouse_right_release
    events = @parser.feed("\e[<2;10;20m")
    assert_equal(1, events.size)
    event = events.first
    assert_equal(:release, event.kind)
    assert_equal(:right, event.button)
  end

  def test_csi_with_many_parameters
    events = @parser.feed("\e[1;2;3;4;5A")
    assert_kind_of(Array, events)
  end

  def test_empty_input
    events = @parser.feed("")
    assert_empty(events)
    refute(@parser.pending?)
  end

  def test_null_byte
    events = @parser.feed("\x00")
    assert_equal(1, events.size)
    event = events.first
    assert_equal(:char, event.code)
    assert_equal(" ", event.char)
    assert(event.ctrl)
  end

  def test_multiple_null_bytes
    events = @parser.feed("\x00\x00\x00")
    assert_equal(3, events.size)
    events.each do |event|
      assert_equal(:char, event.code)
      assert_equal(" ", event.char)
      assert(event.ctrl)
    end
  end
end
