use std::cell::RefCell;

use magnus::{
    Class, Error, IntoValue, IntoValueFromNative, Module, Object, RArray, RClass, RModule, Ruby,
    Symbol, Value, function, kwargs, method, value::Lazy,
};
use vte::{Params, Perform};

const MODIFIER_SHIFT: u16 = 0x01;
const MODIFIER_ALT: u16 = 0x02;
const MODIFIER_CTRL: u16 = 0x04;

const MOUSE_BUTTON_MASK: u16 = 0x03;
const MOUSE_SHIFT: u16 = 0x04;
const MOUSE_ALT: u16 = 0x08;
const MOUSE_CTRL: u16 = 0x10;
const MOUSE_MOTION: u16 = 0x20;
const MOUSE_SCROLL: u16 = 0x40;
const MOUSE_SCROLL_DOWN: u16 = 0x01;

static VTX_MODULE: Lazy<RModule> = Lazy::new(|ruby| ruby.define_module("Vtx").unwrap());

macro_rules! vtx_class {
    ($name:ident, $class:literal) => {
        static $name: Lazy<RClass> = Lazy::new(|ruby| {
            ruby.get_inner(&VTX_MODULE)
                .const_get::<_, RClass>($class)
                .unwrap()
        });
    };
}

vtx_class!(KEY_CLASS, "Key");
vtx_class!(MOUSE_CLASS, "Mouse");
vtx_class!(PASTE_CLASS, "Paste");
vtx_class!(FOCUS_CLASS, "Focus");

#[derive(Debug, Clone)]
enum Event {
    Key {
        code: KeyCode,
        char: Option<char>,
        ctrl: bool,
        alt: bool,
        shift: bool,
    },
    Mouse {
        kind: MouseKind,
        button: MouseButton,
        row: u16,
        col: u16,
        ctrl: bool,
        alt: bool,
        shift: bool,
    },
    Paste(String),
    Focus(bool),
}

unsafe impl IntoValueFromNative for Event {}

impl IntoValue for Event {
    fn into_value_with(self, ruby: &Ruby) -> Value {
        match self {
            Event::Key {
                code,
                char,
                ctrl,
                alt,
                shift,
            } => {
                let code = code.to_symbol(ruby);
                let kwargs = kwargs!("code" => code, "char" => char, "ctrl" => ctrl, "alt" => alt, "shift" => shift);
                ruby.get_inner(&KEY_CLASS).new_instance((kwargs,))
            }
            Event::Mouse {
                kind,
                button,
                row,
                col,
                ctrl,
                alt,
                shift,
            } => {
                let kind = ruby.to_symbol(kind.as_str());
                let button = ruby.to_symbol(button.as_str());
                let kwargs = kwargs!("kind" => kind, "button" => button, "row" => row, "col" => col, "ctrl" => ctrl, "alt" => alt, "shift" => shift);
                ruby.get_inner(&MOUSE_CLASS).new_instance((kwargs,))
            }
            Event::Paste(content) => {
                let kwargs = kwargs!("content" => content.as_str());
                ruby.get_inner(&PASTE_CLASS).new_instance((kwargs,))
            }
            Event::Focus(focused) => {
                let kwargs = kwargs!("focused" => focused);
                ruby.get_inner(&FOCUS_CLASS).new_instance((kwargs,))
            }
        }
        .expect("failed to instantiate class")
    }
}

#[derive(Debug, Clone, Copy)]
enum KeyCode {
    Char,
    Enter,
    Escape,
    Tab,
    Backspace,
    Delete,
    Up,
    Down,
    Left,
    Right,
    Home,
    End,
    PageUp,
    PageDown,
    Insert,
    F(u8),
}

impl KeyCode {
    fn to_symbol(self, ruby: &Ruby) -> Symbol {
        match self {
            KeyCode::F(n) => ruby.to_symbol(format!("f{}", n)),
            other => ruby.to_symbol(other.as_str()),
        }
    }

    fn as_str(self) -> &'static str {
        match self {
            KeyCode::Char => "char",
            KeyCode::Enter => "enter",
            KeyCode::Escape => "escape",
            KeyCode::Tab => "tab",
            KeyCode::Backspace => "backspace",
            KeyCode::Delete => "delete",
            KeyCode::Up => "up",
            KeyCode::Down => "down",
            KeyCode::Left => "left",
            KeyCode::Right => "right",
            KeyCode::Home => "home",
            KeyCode::End => "end",
            KeyCode::PageUp => "page_up",
            KeyCode::PageDown => "page_down",
            KeyCode::Insert => "insert",
            KeyCode::F(_) => unreachable!("F keys handled separately in to_symbol"),
        }
    }
}

#[derive(Debug, Clone, Copy)]
enum MouseKind {
    Press,
    Release,
    Drag,
    Move,
    ScrollUp,
    ScrollDown,
}

impl MouseKind {
    fn as_str(self) -> &'static str {
        match self {
            MouseKind::Press => "press",
            MouseKind::Release => "release",
            MouseKind::Drag => "drag",
            MouseKind::Move => "move",
            MouseKind::ScrollUp => "scroll_up",
            MouseKind::ScrollDown => "scroll_down",
        }
    }
}

#[derive(Debug, Clone, Copy)]
enum MouseButton {
    Left,
    Middle,
    Right,
    None,
}

impl MouseButton {
    fn as_str(self) -> &'static str {
        match self {
            MouseButton::Left => "left",
            MouseButton::Middle => "middle",
            MouseButton::Right => "right",
            MouseButton::None => "none",
        }
    }
}

#[derive(Debug, Default)]
struct PerformerState {
    preceding_char: Option<char>,
    paste_buffer: Option<String>,
    pending_ss3: bool,
}

struct Performer<'a> {
    state: &'a mut PerformerState,
    events: Vec<Event>,
}

impl<'a> Performer<'a> {
    fn new(state: &'a mut PerformerState) -> Self {
        Self {
            state,
            events: Vec::new(),
        }
    }

    fn push_key(&mut self, code: KeyCode, char: Option<char>, ctrl: bool, alt: bool, shift: bool) {
        self.events.push(Event::Key {
            code,
            char,
            ctrl,
            alt,
            shift,
        });
    }

    fn push_simple_key(&mut self, code: KeyCode) {
        self.push_key(code, None, false, false, false);
    }

    fn parse_modifiers(param: u16) -> (bool, bool, bool) {
        let m = param.saturating_sub(1);
        (
            m & MODIFIER_CTRL != 0,
            m & MODIFIER_ALT != 0,
            m & MODIFIER_SHIFT != 0,
        )
    }

    fn push_key_with_modifiers(&mut self, code: KeyCode, params: &[u16]) {
        let (ctrl, alt, shift) = params
            .get(1)
            .map_or((false, false, false), |&p| Self::parse_modifiers(p));

        self.push_key(code, None, ctrl, alt, shift);
    }
}

impl Performer<'_> {
    fn handle_ss3(&mut self, byte: u8) {
        let code = match byte {
            b'A' => KeyCode::Up,
            b'B' => KeyCode::Down,
            b'C' => KeyCode::Right,
            b'D' => KeyCode::Left,
            b'F' => KeyCode::End,
            b'H' => KeyCode::Home,
            b'P' => KeyCode::F(1),
            b'Q' => KeyCode::F(2),
            b'R' => KeyCode::F(3),
            b'S' => KeyCode::F(4),
            _ => return,
        };

        self.push_simple_key(code);
    }

    fn handle_sgr_mouse(&mut self, params: &[u16], pressed: bool) {
        let button_flags = params.first().copied().unwrap_or(0);
        let col = params.get(1).map_or(0, |&v| v.saturating_sub(1));
        let row = params.get(2).map_or(0, |&v| v.saturating_sub(1));

        let shift = button_flags & MOUSE_SHIFT != 0;
        let alt = button_flags & MOUSE_ALT != 0;
        let ctrl = button_flags & MOUSE_CTRL != 0;
        let is_motion = button_flags & MOUSE_MOTION != 0;
        let is_scroll = button_flags & MOUSE_SCROLL != 0;

        let (kind, button) = if is_scroll {
            let kind = if button_flags & MOUSE_SCROLL_DOWN != 0 {
                MouseKind::ScrollDown
            } else {
                MouseKind::ScrollUp
            };
            (kind, MouseButton::None)
        } else {
            let button = match button_flags & MOUSE_BUTTON_MASK {
                0 => MouseButton::Left,
                1 => MouseButton::Middle,
                2 => MouseButton::Right,
                _ => MouseButton::None,
            };

            let kind = match (is_motion, pressed) {
                (true, true) => MouseKind::Drag,
                (true, false) => MouseKind::Move,
                (false, true) => MouseKind::Press,
                (false, false) => MouseKind::Release,
            };

            (kind, button)
        };

        self.events.push(Event::Mouse {
            kind,
            button,
            row,
            col,
            ctrl,
            alt,
            shift,
        });
    }

    fn handle_kitty_keyboard(&mut self, params: &[u16]) {
        let keycode = params.first().copied().unwrap_or(0);
        let (ctrl, alt, shift) = params
            .get(1)
            .map_or((false, false, false), |&p| Self::parse_modifiers(p));

        let (code, char) = match keycode {
            9 => (KeyCode::Tab, None),
            13 => (KeyCode::Enter, None),
            27 => (KeyCode::Escape, None),
            127 => (KeyCode::Backspace, None),
            _ => match char::from_u32(keycode as u32) {
                Some(c) => (KeyCode::Char, Some(c)),
                None => return,
            },
        };

        self.push_key(code, char, ctrl, alt, shift);
    }

    fn append_csi_to_paste_buffer(&mut self, params: &[u16], intermediates: &[u8], action: char) {
        if let Some(buf) = &mut self.state.paste_buffer {
            buf.push('\x1b');
            buf.push('[');
            for &b in intermediates {
                buf.push(b as char);
            }
            let has_non_default = params.iter().any(|&p| p != 0);
            if has_non_default {
                for (i, p) in params.iter().enumerate() {
                    if i > 0 {
                        buf.push(';');
                    }
                    use std::fmt::Write;
                    let _ = write!(buf, "{}", p);
                }
            }
            buf.push(action);
        }
    }
}

impl Perform for Performer<'_> {
    fn print(&mut self, c: char) {
        if self.state.pending_ss3 {
            self.state.pending_ss3 = false;
            return self.handle_ss3(c as u8);
        }

        if let Some(buf) = &mut self.state.paste_buffer {
            buf.push(c);
            return;
        }

        self.state.preceding_char = Some(c);

        let (code, char) = if c == '\x7f' {
            (KeyCode::Backspace, None)
        } else {
            (KeyCode::Char, Some(c))
        };

        self.push_key(code, char, false, false, false);
    }

    fn execute(&mut self, byte: u8) {
        if let Some(buf) = &mut self.state.paste_buffer {
            if let Some(c) = char::from_u32(byte as u32) {
                buf.push(c);
            }
            return;
        }

        match byte {
            0x00 => self.push_key(KeyCode::Char, Some(' '), true, false, false),
            0x08 => self.push_simple_key(KeyCode::Backspace),
            0x09 => self.push_simple_key(KeyCode::Tab),
            0x0D => self.push_simple_key(KeyCode::Enter),
            0x01..=0x1A => {
                let c = (byte + 0x60) as char;
                self.push_key(KeyCode::Char, Some(c), true, false, false);
            }
            0x7F => self.push_simple_key(KeyCode::Backspace),
            _ => {}
        }
    }

    fn csi_dispatch(&mut self, params: &Params, intermediates: &[u8], ignore: bool, action: char) {
        let params: Vec<u16> = params.iter().flat_map(|p| p.iter().copied()).collect();

        if action == '~' && intermediates.is_empty() && params.first() == Some(&201) {
            if let Some(content) = self.state.paste_buffer.take() {
                self.events.push(Event::Paste(content));
            }
            return;
        }

        if self.state.paste_buffer.is_some() {
            self.append_csi_to_paste_buffer(&params, intermediates, action);
            return;
        }

        if ignore || intermediates.len() > 2 {
            return;
        }

        match (action, intermediates) {
            ('A', []) => self.push_key_with_modifiers(KeyCode::Up, &params),
            ('B', []) => self.push_key_with_modifiers(KeyCode::Down, &params),
            ('C', []) => self.push_key_with_modifiers(KeyCode::Right, &params),
            ('D', []) => self.push_key_with_modifiers(KeyCode::Left, &params),
            ('F', []) => self.push_key_with_modifiers(KeyCode::End, &params),
            ('H', []) => self.push_key_with_modifiers(KeyCode::Home, &params),
            ('Z', []) => self.push_key(KeyCode::Tab, None, false, false, true),
            ('I', []) => self.events.push(Event::Focus(true)),
            ('O', []) => self.events.push(Event::Focus(false)),
            ('M', [b'<']) | ('m', [b'<']) => self.handle_sgr_mouse(&params, action == 'M'),
            ('u', []) => self.handle_kitty_keyboard(&params),
            ('b', []) => {
                let Some(c) = self.state.preceding_char else {
                    return;
                };
                let count = params.first().copied().unwrap_or(1).max(1);
                for _ in 0..count {
                    self.push_key(KeyCode::Char, Some(c), false, false, false);
                }
            }
            ('~', []) => {
                let key_num = params.first().copied().unwrap_or(0);
                match key_num {
                    1 | 7 => self.push_key_with_modifiers(KeyCode::Home, &params),
                    2 => self.push_key_with_modifiers(KeyCode::Insert, &params),
                    3 => self.push_key_with_modifiers(KeyCode::Delete, &params),
                    4 | 8 => self.push_key_with_modifiers(KeyCode::End, &params),
                    5 => self.push_key_with_modifiers(KeyCode::PageUp, &params),
                    6 => self.push_key_with_modifiers(KeyCode::PageDown, &params),
                    15 => self.push_key_with_modifiers(KeyCode::F(5), &params),
                    17 => self.push_key_with_modifiers(KeyCode::F(6), &params),
                    18 => self.push_key_with_modifiers(KeyCode::F(7), &params),
                    19 => self.push_key_with_modifiers(KeyCode::F(8), &params),
                    20 => self.push_key_with_modifiers(KeyCode::F(9), &params),
                    21 => self.push_key_with_modifiers(KeyCode::F(10), &params),
                    23 => self.push_key_with_modifiers(KeyCode::F(11), &params),
                    24 => self.push_key_with_modifiers(KeyCode::F(12), &params),
                    200 => self.state.paste_buffer = Some(String::new()),
                    _ => {}
                }
            }
            _ => {}
        }
    }

    fn esc_dispatch(&mut self, intermediates: &[u8], _ignore: bool, byte: u8) {
        match (byte, intermediates) {
            (b'O', []) => self.state.pending_ss3 = true,
            (0x20..=0x7E, []) => {
                let c = byte as char;
                self.push_key(KeyCode::Char, Some(c), false, true, false);
            }
            _ => {}
        }
    }

    fn hook(&mut self, _params: &Params, _intermediates: &[u8], _ignore: bool, _action: char) {}
    fn put(&mut self, _byte: u8) {}
    fn unhook(&mut self) {}
    fn osc_dispatch(&mut self, _params: &[&[u8]], _bell_terminated: bool) {}
}

#[magnus::wrap(class = "Vtx::NativeParser")]
struct Parser {
    inner: RefCell<vte::Parser>,
    state: RefCell<PerformerState>,
    pending_esc: RefCell<bool>,
}

impl Parser {
    fn new() -> Self {
        Self {
            inner: RefCell::new(vte::Parser::new()),
            state: RefCell::new(PerformerState::default()),
            pending_esc: RefCell::new(false),
        }
    }

    fn parse(&self, input: String) -> Result<RArray, Error> {
        let ruby = Ruby::get().expect("ruby unavailable");

        let mut state = self.state.borrow_mut();
        let mut performer = Performer::new(&mut state);
        let bytes = input.as_bytes();

        self.inner.borrow_mut().advance(&mut performer, bytes);

        let ends_with_esc = bytes.last() == Some(&0x1B);
        let produced_events = !performer.events.is_empty();
        let events = std::mem::take(&mut performer.events);
        drop(performer);

        let has_pending_ss3 = state.pending_ss3;

        *self.pending_esc.borrow_mut() = (ends_with_esc && !produced_events) || has_pending_ss3;

        Ok(ruby.ary_from_vec(events))
    }

    fn pending(&self) -> bool {
        *self.pending_esc.borrow()
    }

    fn flush(&self) -> Result<RArray, Error> {
        let ruby = Ruby::get().expect("ruby unavailable");
        let array = ruby.ary_new();

        if self.pending() {
            *self.pending_esc.borrow_mut() = false;
            *self.inner.borrow_mut() = vte::Parser::new();
            self.state.borrow_mut().pending_ss3 = false;

            let event = Event::Key {
                code: KeyCode::Escape,
                char: None,
                ctrl: false,
                alt: false,
                shift: false,
            };
            array.push(event.into_value_with(&ruby))?;
        }

        Ok(array)
    }
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.get_inner(&VTX_MODULE);

    let class = module.define_class("NativeParser", ruby.class_object())?;
    class.define_singleton_method("new", function!(Parser::new, 0))?;
    class.define_method("parse", method!(Parser::parse, 1))?;
    class.define_method("pending?", method!(Parser::pending, 0))?;
    class.define_method("flush", method!(Parser::flush, 0))?;

    Ok(())
}
