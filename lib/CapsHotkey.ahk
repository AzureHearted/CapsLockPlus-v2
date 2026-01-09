#Requires AutoHotkey v2.0
#Include <Console>
#Include <KeysMap>

/** CapsLook热键类 */
class CapsHotkey {
	/** 热键方法映射表
	 * @type {Map<String,Map<String,Object>>} */
	hotkeyFuncMap := Map()

	__New() {

	}

	Init() {
		; 初始化时设置空回调占位
		for (pk, pv in KeysMap.Prefix) {
			; Console.Debug(pk ":" pv)
			;* 字母 & 数字
			for (key in StrSplit(KeysMap.LettersAndNums)) {
				this.AddHotkey("$" pk key, (k) => Console.Debug("按键 `"" k "`" 尚未设置"))
			}
			;* 特殊符号键
			for (key in KeysMap.Symbol) {
				this.AddHotkey("$" pk key, (k) => Console.Debug("按键 `"" k "`" 尚未设置"))
			}
			;* 小键盘区域
			for (key in KeysMap.Numpad) {
				this.AddHotkey("$" pk key, (k) => Console.Debug("按键 `"" k "`" 尚未设置"))
			}
			;* 鼠标操作
			for (key in KeysMap.Mouse) {
				this.AddHotkey("$" pk key, (k) => Console.Debug("按键 `"" k "`" 尚未设置"))
			}
		}
	}

	; f 判断是否按下CapsLook按键
	isCapsHold(*) => GetKeyState("CapsLock", "P")

	/**
	 * f 添加或覆盖热键
	 * @param {String} KeyName 热键的按键的名称, 包括所有修饰符. 例如, 指定 #c 来触发 Win+C 热键.
	 * 
	 * @param {Func|String} Callback 此参数还可以是下列特定值的其中一个:
	 * On: 启用热键. 如果热键已经处于启用状态, 则不进行操作.
	 * Off: 禁用热键. 如果热键已经处于禁用状态, 则不进行操作.
	 * Toggle: 设置热键到相反的状态(启用或禁用).
	 * AltTab(及其他): 这里描述的特殊的 Alt-Tab 热键动作.
	 * 
	 * @param {String} Options 由零个或多个下列字母组成的字符串, 字母间可以用空格分隔. 例如: On B0.
	 * On: 如果热键当前是禁用的, 则启用它.
	 * Off: 如果热键当前是启用的, 则禁用它. 此选项常用来创建初始状态为禁用的热键.
	 * B 或 B0: 指定字母 B 将按照 #MaxThreadsBuffer 中描述的方法缓冲热键. 指定 B0(B 后跟着数字 0) 来禁用这种类型的缓冲.
	 * Pn: 指定字母 P 后面跟着热键的线程优先级. 如果创建热键时省略 P 选项, 则设置优先级为 0.
	 * Tn: 指定字母 T 后面跟着一个表示此热键允许的线程数, 如同 #MaxThreadsPerHotkey 中描述的那样. 例如: T5.
	 * In(InputLevel): 指定字母 I(或 i) 后跟随热键的输入级别. 例如: I1.
	 * 
	 * @param {String} WinTitle 窗口条件(支持正则)
	 * 
	 * @param {Integer} Level 等级越高执行优先级越高
	 */
	AddHotkey(KeyName, Callback, Options?, WinTitle := "", Level := 1) {
		if (!IsObject(Callback) && Type(Callback) != "String")
			return

		call := {
			Enable: true,
			Operation: Callback,
		}
		callMap := this.hotkeyFuncMap.Get(KeysMap.ParseKey(KeyName), Map())
		callMap[WinTitle] := call

		; 记录回调函数
		this.hotkeyFuncMap.Set(KeysMap.ParseKey(KeyName), callMap)

		; 应用 HotIf
		HotIf(this.isCapsHold)
		Hotkey(KeyName, Action)
		Action(HotkeyName) {
			key := KeysMap.ParseKey(HotkeyName)
			try {
				callMap := this.hotkeyFuncMap.Get(key)

				SetTitleMatchMode "RegEx"
				; 先尝试执行有窗口限制条件的操作
				for (WA, call in callMap) {
					; 先跳过默认操作
					if (!WA)
						continue
					if (call.Enable && WA && WinActive(WA)) {
						if (IsObject(call.Operation)) {
							call.Operation.Call(key)
						} else if (Type(call.Operation) == "String") {
							; Console.Debug(key " => (特殊)输出：" call.Operation)
							SendInput(call.Operation)
						} else {
							throw Error(HotkeyName " (" key ")  =>  错误的回调类型（请检查KeyName参数的大小写，以及回调类型，回调类型仅支持Func和String）")
						}
						return
					}
				}

				; 最后循环结束还是没有执行过则判断执行默认操作
				defaultCall := callMap.Get("")
				; Console.Debug("当前call：", defaultCall)
				if (!defaultCall.Enable)
					return
				if (IsObject(defaultCall.Operation)) {
					defaultCall.Operation.Call(key)
				} else if (Type(defaultCall.Operation) == "String") {
					; Console.Debug(key " => 输出：" defaultCall.Operation)
					SendInput(defaultCall.Operation)
				} else {
					throw Error(HotkeyName " (" key ")  =>  错误的回调类型（请检查KeyName参数的大小写，以及回调类型，回调类型仅支持Func和String）")
				}
			} catch as e {
				Console.Error(e)
			} finally {
				SetTitleMatchMode 2
			}
		}
		HotIf()
	}

	/**
	 * f 启用热键的某一个操作
	 * @param {String} KeyName 热键的按键的名称, 包括所有修饰符. 例如, 指定 #c 来触发 Win+C 热键.
	 * @param {String} WinTitle 窗口条件(支持正则)
	 */
	EnableHotkeyOperation(KeyName, WinTitle) {
		callMap := this.hotkeyFuncMap.Get(KeysMap.ParseKey(KeyName), Map())
		call := callMap.Get(WinTitle)
		call.Enable := true
	}

	/**
	 * f 禁用热键的某一个操作
	 * @param {String} KeyName 热键的按键的名称, 包括所有修饰符. 例如, 指定 #c 来触发 Win+C 热键.
	 * @param {String} WinTitle 窗口条件(支持正则)
	 */
	DisableHotkeyOperation(KeyName, WinTitle) {
		callMap := this.hotkeyFuncMap.Get(KeysMap.ParseKey(KeyName), Map())
		call := callMap.Get(WinTitle)
		call.Enable := false
	}

	/**
	 * f 启用热键
	 * @param {String} KeyName 热键的按键的名称, 包括所有修饰符. 例如, 指定 #c 来触发 Win+C 热键.
	 */
	EnableHotkey(KeyName) {
		HotIf(this.isCapsHold)
		Hotkey(KeyName, "On")
		HotIf()
	}

	/**
	 * f 禁用用热键
	 * @param {String} KeyName 热键的按键的名称, 包括所有修饰符. 例如, 指定 #c 来触发 Win+C 热键.
	 */
	DisableHotkey(KeyName) {
		HotIf(this.isCapsHold)
		Hotkey(KeyName, "Off")
		HotIf()
	}
}