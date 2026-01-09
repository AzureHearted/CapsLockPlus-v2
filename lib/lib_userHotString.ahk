#Requires AutoHotkey v2.0
#Include <lib_functions>

; 用户热字符串
class UserHotString {
	; 热字符串Map
	hotStringMap := Map()

	__New(iniPath, sectionName := 'HotString') {
		this.iniPath := iniPath
		this.sectionName := sectionName
		this.Load()
	}

	; 读取ini文件中的HotString配置
	Load() {
		section := IniRead(this.iniPath, this.sectionName, , '')
		list := StrSplit(section, ['`n'])
		for (item in list) {
			iList := StrSplit(item, ['='])
			key := ''
			value := ''
			try {
				key := iList[1]
				value := iList[2]
				; value := RTrim(value)
			} catch Error as e {
				ShowToolTips(e.Message)
			}
			if (value) {
				this.hotStringMap[key] := value
			}
		}
		Console.Debug('[用户HosString] 成功读取')
	}

	; 启用用户HotString
	Enable() {
		Console.Debug('[用户HotString] 已启用')
		this.ControlHotString(this.hotStringMap, 'On')
	}

	; 禁用用用户HotString
	Disable() {
		Console.Debug('已禁用用户HotString')
		; ShowToolTips('已禁用用户HotString')
		this.ControlHotString(this.hotStringMap, 'Off')
	}

	/**
	 * 控制HotString
	 * @param {Map} hsMap 
	 * @param {0|1|-1|"On"|"Off"|"Toggle"} OnOffToggle 
	 */
	ControlHotString(hsMap, OnOffToggle) {
		for (hotKey in hsMap) {
			Hotstring(hotKey, Handle, OnOffToggle)
			Handle(HotstringName) {
				oldClip := ClipboardAll()
				value := this.hotStringMap[HotstringName]
				Console.Debug('输出：' value)
				; SendText(value)
				A_Clipboard := value
				ClipWait()
				SendInput('^v')
				Sleep(50)
				A_Clipboard := oldClip
			}
		}
	}

	; 获取当前输入法
	GetCurrentLayout() {
		tid := DllCall('GetWindowThreadProcessId', 'ptr', WinActive('A'), 'uint', 0)
		hkl := DllCall('GetKeyboardLayout', 'uint', tid, 'ptr')
		return Format("{:08x}", hkl & 0xFFFFFFFF)
	}

	; 切换输入法
	SetLayout(keyboard := "00000409") {
		; 美式键盘布局 ID:00000409
		hkl := DllCall('LoadKeyboardLayoutW', 'Str', "00000409", 'uint', 1, 'ptr')
		DllCall('ActivateKeyboardLayout', 'ptr', hkl, 'uint', 0)
	}


	__Delete() {
		this.ControlHotString(this.hotStringMap, 'Off')
	}
}