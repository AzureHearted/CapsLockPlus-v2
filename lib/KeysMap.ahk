#Requires AutoHotkey v2.0

class KeysMap {
	;? 引导键
	static Prefix := Map(
		"", "",
		"!", "Alt",
		"+", "Shift",
		"#", "Win",
		"^", "Ctrl"
	)
	;? 字母和数字
	static LettersAndNums := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

	;* 特殊符号键（按原来的命名习惯手动枚举）
	static Symbol := Map(
		"``", "Backquote",
		"-", "Minus",
		"=", "Equal",
		"[", "LeftSquareBracket",
		"]", "RightSquareBracket",
		"\", "Backslash",
		";", "Semicolon",
		"'", "Quote",
		",", "Comma",
		".", "Dot",
		"/", "Slash",
		"Backspace", "Backspace",
		"Tab", "Tab",
		"Enter", "Enter",
		"Space", "Space"
	)
	;* 小键盘区域
	static Numpad := Map(
		"NumLock", "NumLock",
		"Numpad0", "0",
		"Numpad1", "1",
		"Numpad2", "2",
		"Numpad3", "3",
		"Numpad4", "4",
		"Numpad5", "5",
		"Numpad6", "6",
		"Numpad7", "7",
		"Numpad8", "8",
		"Numpad9", "9",
		"NumpadAdd", "Equal",
		"NumpadSub", "Minus",
		"NumpadMult", "Mult",
		"NumpadDiv", "Slash",
		"NumpadEnter", "Enter",
		"NumpadDot", "Dot",
	)
	;* 鼠标操作
	static Mouse := Map(
		"WheelUp", "WheelUp",
		"WheelDown", "WheelDown",
		"MButton", "MButton",
		"LButton", "LButton",
		"RButton", "RButton"
	)

	/**
	 * 解析HotKey为可读形式
	 * @example 如：$!A => Caps_Alt_A
	 * @param {String} rawHotkey HotKey 产生的 HotkeyName
	 * @param {String} bootKey 引导键默认Caps
	 * @returns {String} 解析结果
	 */
	static ParseKey(rawHotkey, bootKey := "Caps") {
		rawHotkey := StrReplace(rawHotkey, "$")
		for pk, pv in this.Prefix {
			rawHotkey := StrReplace(rawHotkey, pk, pv ? pv "_" : "")
		}
		return (bootKey ? bootKey "_" : "") rawHotkey
	}
}