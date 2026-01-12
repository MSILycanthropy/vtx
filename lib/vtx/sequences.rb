# frozen_string_literal: true

module Vtx
  module Sequences
    extend self

    CLEAR = "\e[2J"
    CLEAR_BELOW = "\e[0J"
    CLEAR_ABOVE = "\e[1J"
    CLEAR_LINE = "\e[2K"
    CLEAR_LINE_RIGHT = "\e[0K"
    CLEAR_LINE_LEFT = "\e[1K"

    CURSOR_SHOW = "\e[?25h"
    CURSOR_HIDE = "\e[?25l"
    CURSOR_SAVE = "\e[s"
    CURSOR_RESTORE = "\e[u"
    CURSOR_HOME = "\e[H"

    ALTERNATE_SCREEN_ENTER = "\e[?1049h"
    ALTERNATE_SCREEN_LEAVE = "\e[?1049l"
    BRACKETED_PASTE_ENABLE = "\e[?2004h"
    BRACKETED_PASTE_DISABLE = "\e[?2004l"
    FOCUS_EVENTS_ENABLE = "\e[?1004h"
    FOCUS_EVENTS_DISABLE = "\e[?1004l"
    SYNC_OUTPUT_ENABLE = "\e[?2026h"
    SYNC_OUTPUT_DISABLE = "\e[?2026l"

    MOUSE_NORMAL_ENABLE = "\e[?1000h\e[?1006h"
    MOUSE_NORMAL_DISABLE = "\e[?1000l\e[?1006l"
    MOUSE_BUTTON_ENABLE = "\e[?1002h\e[?1006h"
    MOUSE_BUTTON_DISABLE = "\e[?1002l\e[?1006l"
    MOUSE_ALL_ENABLE = "\e[?1003h\e[?1006h"
    MOUSE_ALL_DISABLE = "\e[?1003l\e[?1006l"

    RESET_STYLE = "\e[0m"
    BOLD = "\e[1m"
    DIM = "\e[2m"
    ITALIC = "\e[3m"
    UNDERLINE = "\e[4m"
    BLINK = "\e[5m"
    REVERSE = "\e[7m"
    HIDDEN = "\e[8m"
    STRIKETHROUGH = "\e[9m"

    BELL = "\a"

    def move_to(row, col)
      "\e[#{row + 1};#{col + 1}H"
    end

    def move_up(n = 1)
      "\e[#{n}A"
    end

    def move_down(n = 1)
      "\e[#{n}B"
    end

    def move_forward(n = 1)
      "\e[#{n}C"
    end

    def move_back(n = 1)
      "\e[#{n}D"
    end

    def move_to_next_line(n = 1)
      "\e[#{n}E"
    end

    def move_to_prev_line(n = 1)
      "\e[#{n}F"
    end

    def move_to_column(col)
      "\e[#{col + 1}G"
    end

    def move_to_row(row)
      "\e[#{row + 1}d"
    end

    def scroll_up(n = 1)
      "\e[#{n}S"
    end

    def scroll_down(n = 1)
      "\e[#{n}T"
    end

    def scroll_region(top, bottom)
      "\e[#{top + 1};#{bottom + 1}r"
    end

    def reset_scroll_region
      "\e[r"
    end

    def insert_lines(n = 1)
      "\e[#{n}L"
    end

    def delete_lines(n = 1)
      "\e[#{n}M"
    end

    def insert_chars(n = 1)
      "\e[#{n}@"
    end

    def delete_chars(n = 1)
      "\e[#{n}P"
    end

    def erase_chars(n = 1)
      "\e[#{n}X"
    end

    def title(str)
      "\e]2;#{str}\e\\"
    end

    def icon_name(str)
      "\e]1;#{str}\e\\"
    end

    def hyperlink(url, text, id: nil)
      id_param = id ? "id=#{id}" : ""
      "\e]8;#{id_param};#{url}\e\\#{text}\e]8;;\e\\"
    end

    def hyperlink_start(url, id: nil)
      id_param = id ? "id=#{id}" : ""
      "\e]8;#{id_param};#{url}\e\\"
    end

    def hyperlink_end
      "\e]8;;\e\\"
    end

    def notify(title, body: nil)
      if body
        "\e]777;notify;#{title};#{body}\e\\"
      else
        "\e]777;notify;#{title}\e\\"
      end
    end

    def copy_to_clipboard(text, target: :clipboard)
      encoded = [text].pack("m0")
      target_code = case target
      when :clipboard then "c"
      when :primary then "p"
      when :both then "cp"
      else "c"
      end
      "\e]52;#{target_code};#{encoded}\e\\"
    end

    def foreground(color)
      codes = Color.parse(color, foreground: true)
      codes.empty? ? "" : "\e[#{codes.join(";")}m"
    end

    def background(color)
      codes = Color.parse(color, foreground: false)
      codes.empty? ? "" : "\e[#{codes.join(";")}m"
    end
  end
end
