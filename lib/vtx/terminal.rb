# frozen_string_literal: true

module Vtx
  # Main terminal interface
  #
  # Provides buffered output with terminal manipulation
  #
  # @example Basic Usage
  #   terminal = Vtx::Terminal.new
  #   terminal.enable_raw_mode
  #   terminal.enter_alternate_screen
  #   terminal.print("Hello", foreground: :red)
  #   terminal.flush
  #   terminal.close
  #
  # @example With block
  #   terminal = Vtx::Terminal.new
  #   terminal.sync do
  #     terminal.clear
  #     terminal.move_to(0, 0)
  #     terminal.print("Header", bold: true)
  #   end
  #
  class Terminal
    attr_reader :input, :output

    def initialize(input: $stdin, output: $stdout)
      @input = input
      @output = output
      @buffer = String.new(encoding: Encoding::UTF_8)
      @mutex = Mutex.new
      @state = State.new

      @parser = EventParser.new

      @event_queue = []
    end

    def raw_mode? = @state.raw_mode
    def alternate_screen? = @state.alternate_screen
    def mouse_capture? = !@state.mouse_capture.nil?
    def mouse_capture = @state.mouse_capture
    def bracketed_paste? = @state.bracketed_paste
    def focus_events? = @state.focus_events
    def cursor_visible? = @state.cursor_visible
    def tty? = @input.tty? && @output.tty?

    def enable_raw_mode
      @mutex.synchronize do
        return self if @state.raw_mode
        return self unless @input.tty?

        require "io/console"
        @input.raw!
        @state.raw_mode = true
      end

      self
    end

    def disable_raw_mode
      @mutex.synchronize do
        return self unless @state.raw_mode
        return self unless @input.tty?

        @input.cooked!
        @state.raw_mode = false
      end

      self
    end

    def enter_alternate_screen
      @mutex.synchronize do
        return self if @state.alternate_screen

        @buffer << Sequences::ALTERNATE_SCREEN_ENTER
        @state.alternate_screen = true
      end

      self
    end

    def leave_alternate_screen
      @mutex.synchronize do
        return self unless @state.alternate_screen

        @buffer << Sequences::ALTERNATE_SCREEN_LEAVE
        @state.alternate_screen = false
      end

      self
    end

    def enable_bracketed_paste
      @mutex.synchronize do
        return self if @state.bracketed_paste

        @buffer << Sequences::BRACKETED_PASTE_ENABLE
        @state.bracketed_paste = true
      end

      self
    end

    def disable_bracketed_paste
      @mutex.synchronize do
        return self unless @state.bracketed_paste

        @buffer << Sequences::BRACKETED_PASTE_DISABLE
        @state.bracketed_paste = false
      end

      self
    end

    def enable_focus_events
      @mutex.synchronize do
        return self if @state.focus_events

        @buffer << Sequences::FOCUS_EVENTS_ENABLE
        @state.focus_events = true
      end

      self
    end

    def disable_focus_events
      @mutex.synchronize do
        return self unless @state.focus_events

        @buffer << Sequences::FOCUS_EVENTS_DISABLE
        @state.focus_events = false
      end

      self
    end

    def show_cursor
      @mutex.synchronize do
        return self if @state.cursor_visible

        @buffer << Sequences::CURSOR_SHOW
        @state.cursor_visible = true
      end

      self
    end

    def hide_cursor
      @mutex.synchronize do
        return self unless @state.cursor_visible

        @buffer << Sequences::CURSOR_HIDE
        @state.cursor_visible = false
      end

      self
    end

    def enable_mouse_capture(mode: :normal)
      @mutex.synchronize do
        return self if @state.mouse_capture == mode

        sequence = case mode
        when :normal then Sequences::MOUSE_NORMAL_ENABLE
        when :button then Sequences::MOUSE_BUTTON_ENABLE
        when :all then Sequences::MOUSE_ALL_ENABLE
        else Sequences::MOUSE_NORMAL_ENABLE
        end

        @buffer << sequence
        @state.mouse_capture = mode
      end

      self
    end

    def disable_mouse_capture
      @mutex.synchronize do
        return self if @state.mouse_capture.nil?

        sequence = case @state.mouse_capture
        when :normal then Sequences::MOUSE_NORMAL_DISABLE
        when :button then Sequences::MOUSE_BUTTON_DISABLE
        when :all then Sequences::MOUSE_ALL_DISABLE
        else Sequences::MOUSE_NORMAL_DISABLE
        end

        @buffer << sequence
        @state.mouse_capture = nil
      end

      self
    end

    def move_to(...) = command { Sequences.move_to(...) }
    def move_up(...) = command { Sequences.move_up(...) }
    def move_down(...) = command { Sequences.move_down(...) }
    def move_forward(...) = command { Sequences.move_forward(...) }
    def move_back(...) = command { Sequences.move_back(...) }
    def move_home = command { Sequences::CURSOR_HOME }
    def move_to_column(...) = command { Sequences.move_to_column(...) }
    def move_to_row(...) = command { Sequences.move_to_row(...) }
    def move_to_next_line(...) = command { Sequences.move_to_next_line(...) }
    def move_to_prev_line(...) = command { Sequences.move_to_prev_line(...) }
    def save_cursor = command { Sequences::CURSOR_SAVE }
    def restore_cursor = command { Sequences::CURSOR_RESTORE }

    def clear = command { Sequences::CLEAR }
    def clear_below = command { Sequences::CLEAR_BELOW }
    def clear_above = command { Sequences::CLEAR_ABOVE }
    def clear_line = command { Sequences::CLEAR_LINE }
    def clear_line_right = command { Sequences::CLEAR_LINE_RIGHT }
    def clear_line_left = command { Sequences::CLEAR_LINE_LEFT }
    def scroll_up(...) = command { Sequences.scroll_up(...) }
    def scroll_down(...) = command { Sequences.scroll_down(...) }
    def set_scroll_region(...) = command { Sequences.scroll_region(...) }
    def reset_scroll_region = command { Sequences.reset_scroll_region }
    def insert_lines(...) = command { Sequences.insert_lines(...) }
    def delete_lines(...) = command { Sequences.delete_lines(...) }
    def insert_chars(...) = command { Sequences.insert_chars(...) }
    def delete_chars(...) = command { Sequences.delete_chars(...) }
    def erase_chars(...) = command { Sequences.erase_chars(...) }

    def title(...) = command { Sequences.title(...) }
    def icon_name(...) = command { Sequences.icon_name(...) }
    def bell = command { Sequences::BELL }
    def notify(...) = command { Sequences.notify(...) }

    def copy_to_clipboard(...) = command { Sequences.copy_to_clipboard(...) }

    def hyperlink(...) = command { Sequences.hyperlink(...) }
    def hyperlink_start(...) = command { Sequences.hyperlink_start(...) }
    def hyperlink_end = command { Sequences.hyperlink_end }

    def write(*args)
      str = args.join

      @mutex.synchronize { @buffer << str }

      str.bytesize
    end

    def print(*args, style: nil, **style_options)
      str = if style || style_options.any?
        resolved = resolve_style(style, style_options)
        "#{resolved}#{args.join}#{Sequences::RESET_STYLE}"
      else
        args.join
      end

      write(str)

      nil
    end

    def puts(*args, style: nil, **style_options)
      str = if args.empty?
        "\n"
      elsif style || style_options.any?
        resolved = resolve_style(style, style_options)
        args.map { |a| "#{resolved}#{a}#{Sequences::RESET_STYLE}\n" }.join
      else
        args.map { |a| "#{a}\n" }.join
      end

      write(str)

      nil
    end

    def flush
      @mutex.synchronize do
        return self if @buffer.empty?

        @output.write(@buffer)
        @output.flush
        @buffer.clear
      end

      self
    end

    def sync
      command { Sequences::SYNC_OUTPUT_ENABLE }

      yield
    ensure
      command { Sequences::SYNC_OUTPUT_DISABLE }

      flush
    end

    def read(...) = @input.read(...)
    def read_nonblock(...) = @input.read_nonblock(...)
    def readpartial(...) = @input.readpartial(...)
    def getc = @input.getc
    def getbyte = @input.getbyte

    def with_cursor
      save_cursor
      yield
    ensure
      restore_cursor
    end

    def size = @state.size ||= query_size
    def refresh_size! = @state.size = query_size

    def resize(cols, rows)
      @state.size = [rows, cols]

      self
    end

    def read_event(timeout: nil)
      deadline = timeout ? Time.now + timeout : nil

      loop do
        event = @event_queue.shift

        return event unless event.nil?

        return unless wait_for_input?(deadline)

        bytes = begin
          read_nonblock(4096)
        rescue IO::WaitReadable, EOFError
          nil
        end

        next if bytes.nil?

        events = @parser.feed(bytes)

        return enqueue_and_return(events) unless events.empty?
      end
    end

    def each_event(timeout: nil)
      return enum_for(:each_event, timeout:) unless block_given?

      loop do
        event = read_event(timeout:)
        yield event if event
      end
    end

    def reset
      disable_focus_events
      disable_bracketed_paste
      disable_mouse_capture
      show_cursor
      leave_alternate_screen
      disable_raw_mode
      flush

      self
    end

    def close
      reset
    end

    def scoped = Scope.new(self)

    private

    def command
      @mutex.synchronize { @buffer << yield }

      self
    end

    def wait_for_input?(deadline)
      return wait_for_pending_escape?(deadline) if @parser.pending?

      wait_for_new_input?(deadline)
    end

    def wait_for_pending_escape?(deadline)
      remaining = remaining_time(deadline)
      remaining = [remaining, @parser.pending_timeout].min if remaining
      remaining ||= @parser.pending_timeout

      if remaining <= 0 || !@input.wait_readable(remaining)
        events = @parser.flush
        @event_queue.concat(events)
        return !events.empty? || (deadline.nil? || Time.now < deadline)
      end

      true
    end

    def wait_for_new_input?(deadline)
      remaining = remaining_time(deadline)
      return false if remaining&.negative?

      @input.wait_readable(remaining)
    end

    def remaining_time(deadline)
      deadline ? deadline - Time.now : nil
    end

    def enqueue(events)
      @event_queue.concat(events)
    end

    def enqueue_and_return(events)
      return if events.empty?

      enqueue(events[1..]) if events.length > 1
      events.first
    end

    def resolve_style(style, options)
      return style.merge(**options) if !style.nil? && options.any?
      return style unless style.nil?

      Style.new(**options)
    end

    def query_size
      return unless @output.tty?

      return @output.winsize if @output.respond_to?(:winsize)

      rows = ENV["LINES"].to_i
      cols = ENV["COLUMNS"].to_i

      [rows, cols]
    end
  end
end
