# frozen_string_literal: true

require "test_helper"

class TestTerminalEvents < Minitest::Test
  def setup
    @read_io, @write_io = IO.pipe
    @output = StringIO.new
    @term = Vtx::Terminal.new(input: @read_io, output: @output)
  end

  def teardown
    @read_io.close unless @read_io.closed?
    @write_io.close unless @write_io.closed?
  end

  def test_read_event_simple_char
    @write_io.write("a")
    @write_io.flush

    event = @term.read_event(timeout: 0.1)

    assert_instance_of(Vtx::Key, event)
    assert_equal(:char, event.code)
    assert_equal("a", event.char)
  end

  def test_read_event_arrow_key
    @write_io.write("\e[A")
    @write_io.flush

    event = @term.read_event(timeout: 0.1)

    assert_instance_of(Vtx::Key, event)
    assert_equal(:up, event.code)
  end

  def test_read_event_multiple_chars_queued
    @write_io.write("abc")
    @write_io.flush

    event1 = @term.read_event(timeout: 0.1)
    event2 = @term.read_event(timeout: 0.1)
    event3 = @term.read_event(timeout: 0.1)

    assert_equal("a", event1.char)
    assert_equal("b", event2.char)
    assert_equal("c", event3.char)
  end

  def test_read_event_timeout_returns_nil
    event = @term.read_event(timeout: 0.01)

    assert_nil(event)
  end

  def test_read_event_escape_timeout_flush
    @write_io.write("\e")
    @write_io.flush

    event = @term.read_event(timeout: 0.1)

    assert_instance_of(Vtx::Key, event)
    assert_equal(:escape, event.code)
  end

  def test_read_event_mouse
    @write_io.write("\e[<0;10;20M")
    @write_io.flush

    event = @term.read_event(timeout: 0.1)

    assert_instance_of(Vtx::Mouse, event)
    assert_equal(:press, event.kind)
    assert_equal(:left, event.button)
    assert_equal(9, event.col) # 0-indexed
  end

  def test_read_event_paste
    @write_io.write("\e[200~hello world\e[201~")
    @write_io.flush

    event = @term.read_event(timeout: 0.1)

    assert_instance_of(Vtx::Paste, event)
    assert_equal("hello world", event.content)
  end

  def test_read_event_focus
    @write_io.write("\e[I")
    @write_io.flush

    event = @term.read_event(timeout: 0.1)

    assert_instance_of(Vtx::Focus, event)
    assert(event.focused?)
  end

  def test_each_event_returns_enumerator
    enum = @term.each_event(timeout: 0.01)

    assert_kind_of(Enumerator, enum)
  end

  def test_sync_wraps_with_sync_sequences
    @term.sync do
      @term.print("hello")
    end

    output = @output.string
    assert(output.start_with?("\e[?2026h"), "Should start with sync enable")
    assert(output.include?("hello"))
    assert(output.end_with?("\e[?2026l"), "Should end with sync disable")
  end

  def test_resize_sets_size
    @term.resize(120, 40)

    assert_equal([120, 40], @term.size)
  end

  def test_resize_returns_self
    assert_same(@term, @term.resize(80, 24))
  end
end
