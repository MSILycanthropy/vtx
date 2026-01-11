# frozen_string_literal: true

module Vtx
  module Adapters
    # Standard ANSI/VT escape sequences.
    #
    # Include this module in adapters that communicate via ANSI escape codes.
    # All methods return escape sequence strings — the adapter is responsible
    # for writing them to the output.
    #
    module AnsiSequences
      def enter_alternate_screen = "\e[?1049h"
      def leave_alternate_screen = "\e[?1049l"

      def enable_mouse_capture(mode)
        case mode
        when :normal then "\e[?1000h\e[?1006h"
        when :button then "\e[?1002h\e[?1006h"
        when :all    then "\e[?1003h\e[?1006h"
        else "\e[?1000h\e[?1006h"
        end
      end

      def disable_mouse_capture = "\e[?1000l\e[?1002l\e[?1003l\e[?1006l"
      def enable_bracketed_paste = "\e[?2004h"
      def disable_bracketed_paste = "\e[?2004l"
      def enable_focus_events = "\e[?1004h"
      def disable_focus_events = "\e[?1004l"
      def enable_sync_output = "\e[?2026h"
      def disable_sync_output = "\e[?2026l"

      def move_to(row, col) = "\e[#{row + 1};#{col + 1}H"
      def move_up(n = 1) = "\e[#{n}A"
      def move_down(n = 1) = "\e[#{n}B"
      def move_forward(n = 1) = "\e[#{n}C"
      def move_back(n = 1) = "\e[#{n}D"
      def move_to_next_line(n = 1) = "\e[#{n}E"
      def move_to_prev_line(n = 1) = "\e[#{n}F"
      def move_to_column(col) = "\e[#{col + 1}G"
      def move_to_row(row) = "\e[#{row + 1}d"
      def move_home = "\e[H"
      def save_cursor = "\e7"
      def restore_cursor = "\e8"
      def show_cursor = "\e[?25h"
      def hide_cursor = "\e[?25l"

      def clear = "\e[2J"
      def clear_below = "\e[0J"
      def clear_above = "\e[1J"
      def clear_line = "\e[2K"
      def clear_line_right = "\e[0K"
      def clear_line_left = "\e[1K"
      def scroll_up(n = 1) = "\e[#{n}S"
      def scroll_down(n = 1) = "\e[#{n}T"
      def set_scroll_region(top, bottom) = "\e[#{top + 1};#{bottom + 1}r"
      def reset_scroll_region = "\e[r"
      def insert_lines(n = 1) = "\e[#{n}L"
      def delete_lines(n = 1) = "\e[#{n}M"
      def insert_chars(n = 1) = "\e[#{n}@"
      def delete_chars(n = 1) = "\e[#{n}P"
      def erase_chars(n = 1) = "\e[#{n}X"

      def reset_style = "\e[0m"

      def style(foreground: nil, background: nil, bold: false, dim: false, italic: false, underline: false,
        blink: false, reverse: false, hidden: false, strikethrough: false)
        codes = []

        codes << 1 if bold
        codes << 2 if dim
        codes << 3 if italic
        codes << 4 if underline
        codes << 5 if blink
        codes << 7 if reverse
        codes << 8 if hidden
        codes << 9 if strikethrough

        codes.concat(Color.parse(foreground, foreground: true)) if foreground
        codes.concat(Color.parse(background, foreground: false)) if background

        return "" if codes.empty?

        "\e[#{codes.join(";")}m"
      end

      def title(str) = "\e]2;#{sanitize_osc(str)}\e\\"
      def icon_name(str) = "\e]1;#{sanitize_osc(str)}\e\\"

      def copy_to_clipboard(text, target: :clipboard)
        target_char = case target
        when :clipboard then "c"
        when :primary then "p"
        when :both then "pc"
        else "c"
        end

        encoded = Base64.strict_encode64(text)
        "\e]52;#{target_char};#{encoded}\e\\"
      end

      def request_clipboard(target: :clipboard)
        target_char = target == :primary ? "p" : "c"
        "\e]52;#{target_char};?\e\\"
      end

      def hyperlink_start(url, id: nil)
        params = id ? "id=#{sanitize_osc(id)}" : ""
        "\e]8;#{params};#{sanitize_osc(url)}\e\\"
      end

      def hyperlink_end = "\e]8;;\e\\"

      def hyperlink(url, text, id: nil)
        "#{hyperlink_start(url, id:)}#{text}#{hyperlink_end}"
      end

      def bell = "\a"

      def notify(title, body: nil)
        return "\e]777;notify;#{sanitize_osc(title)}\e\\" if body.nil?

        "\e]777;notify;#{sanitize_osc(title)};#{sanitize_osc(body)}\e\\"
      end

      private

      def sanitize_osc(text)
        text.to_s.gsub(/[\x00-\x1f\x07\\]/, "")
      end
    end
  end
end
