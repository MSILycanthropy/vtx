# frozen_string_literal: true

module Vtx
  # Main terminal interface
  #
  # Wraps an adapter and provides buffered output with terminal manipulation
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
    def initialize(input: $stdin, output: $stdout, adapter: nil)
      @adapter = adapter || Adapters::Ansi.new(input:, output:)
      @buffer = String.new(encoding: Encoding::UTF_8)
      @mutex = Mutex.new
      @state = State.new
    end

    class << self
      private

      def stateful_command(name, state_key, state_value, adapter_method = name)
        define_method(name) do |*args, **kwargs|
          @mutex.synchronize do
            return self if @state.public_send(state_key) == state_value

            result = if kwargs.any?
              @adapter.public_send(adapter_method, *args, **kwargs)
            elsif args.any?
              @adapter.public_send(adapter_method, *args)
            else
              @adapter.public_send(adapter_method)
            end

            return self unless result

            @buffer << result if result.is_a?(String)
            @state.public_send(:"#{state_key}=", state_value)
          end

          self
        end
      end

      def delegate_command(*methods)
        methods.each do |method|
          define_method(method) do |*args, **kwargs, &block|
            command { @adapter.public_send(method, *args, **kwargs, &block) }
          end
        end
      end
    end

    def raw_mode? = @state.raw_mode?
    def alternate_screen? = @state.alternate_screen?
    def mouse_capture? = !@state.mouse_capture.nil?
    def mouse_capture = @state.mouse_capture
    def bracketed_paste? = @state.bracketed_paste?
    def focus_events? = @state.focus_events?
    def cursor_visible? = @state.cursor_visible?
    def tty? = @adapter.input.tty? && @adapter.output.tty?

    stateful_command :enable_raw_mode, :raw_mode, true
    stateful_command :disable_raw_mode, :raw_mode, false
    stateful_command :enter_alternate_screen, :alternate_screen, true
    stateful_command :leave_alternate_screen, :alternate_screen, false
    stateful_command :enable_bracketed_paste, :bracketed_paste, true
    stateful_command :disable_bracketed_paste, :bracketed_paste, false
    stateful_command :enable_focus_events, :focus_events, true
    stateful_command :disable_focus_events, :focus_events, false
    stateful_command :show_cursor, :cursor_visible, true
    stateful_command :hide_cursor, :cursor_visible, false
    stateful_command :disable_mouse_capture, :mouse_capture, nil

    delegate_command :move_to,
      :move_up,
      :move_down,
      :move_forward,
      :move_back,
      :move_home,
      :move_to_column,
      :move_to_row,
      :move_to_next_line,
      :move_to_prev_line,
      :save_cursor,
      :restore_cursor,
      :clear,
      :clear_below,
      :clear_above,
      :clear_line,
      :clear_line_right,
      :clear_line_left,
      :scroll_up,
      :scroll_down,
      :set_scroll_region,
      :reset_scroll_region,
      :insert_lines,
      :delete_lines,
      :insert_chars,
      :delete_chars,
      :erase_chars,
      :title,
      :icon_name,
      :bell,
      :notify,
      :copy_to_clipboard,
      :request_clipboard,
      :hyperlink,
      :hyperlink_start,
      :hyperlink_end

    def enable_mouse_capture(mode: :normal)
      @mutex.synchronize do
        return self if @state.mouse_capture == mode

        result = @adapter.enable_mouse_capture(mode)
        return self unless result

        @buffer << result if result.is_a?(String)
        @state.mouse_capture = mode
      end

      self
    end

    def print(str, style: nil, **style_options)
      command do
        if style || style_options.any?
          resolved = resolve_style(style, style_options)
          "#{resolved}#{str}#{@adapter.reset_style}"
        else
          str.to_s
        end
      end
    end

    def puts(str = "", style: nil, **style_opts)
      command do
        if style || style_opts.any?
          resolved = resolve_style(style, style_opts)
          "#{resolved}#{str}#{@adapter.reset_style}\n"
        else
          "#{str}\n"
        end
      end
    end

    def flush
      @mutex.synchronize do
        return self if @buffer.empty?

        @adapter.write(@buffer)
        @adapter.flush
        @buffer.clear
      end

      self
    end

    def sync
      yield
    ensure
      flush
    end

    def with_cursor
      save_cursor
      yield
    ensure
      restore_cursor
    end

    def size = @state.size ||= @adapter.size
    def size! = @state.size = @adapter.size
    def cursor_position = @adapter.cursor_position
    def capabilities = @adapter.capabilities

    def read_event(timeout: nil)
      raise NotImplementedError
    end

    def each_event(timeout: nil)
      return enum_for(:each_event, timeout:) unless block_given?

      loop do
        event = read_event(timeout:)
        yield event if event
      end
    end

    # NOTE: I like how simple this method is
    # but this could cause mutex contention?
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

      @adapter.close
    end

    def scoped
      Scope.new(self)
    end

    private

    def command
      @mutex.synchronize { @buffer << yield }

      self
    end

    def resolve_style(style, options)
      return style.merge(**options) if !style.nil? && options.any?
      return style unless style.nil?

      Style.new(**options)
    end
  end
end
