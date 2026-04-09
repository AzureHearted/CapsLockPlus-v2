#Requires AutoHotkey v2.0
#Include <lib_functions>
#Include <lib_controlAlwaysOnTop>

; f CapsLock 开关逻辑
funcLogic_capsSwitch() {
	global CapsLockOpen
	CapsLockOpen := !CapsLockOpen
	SetCapsLockState(CapsLockOpen)
	ShowToolTips("CapsLock键(已" (CapsLockOpen ? '开启' : '关闭') ")")
}

; f CapsLock 按住逻辑
funcLogic_capsHold() {
	;* 防止当前线程被其他线程中断, 或使其能够被中断.
	; Critical "On"

	global CapsLockHold, UserConfig, UISets

	if (CapsLockHold || UISets.hotTips.isShow) {
		return
	}

	CapsLockHold := true
	isDbClick := false ; 是否已经双击选项了(每次每一次显示一旦isDbClick被置为true则直接停止循环)
	mouseButtons := ["MButton", "LButton", "RButton", "WheelUp", "WheelDown"]
	; Console.Debug('-----开始计时-----' A_TickCount - timer)
	while (!isDbClick && GetKeyState('CapsLock', 'P') && (A_ThisHotkey == "CapsLock" || StrIncludesAny(A_ThisHotkey, mouseButtons))) {
		if (UISets.hotTips.isShow) {
			Sleep(50)
			continue
		}

		; Console.Debug('时间差：' A_TimeSinceThisHotkey '`tA_ThisHotkey:' A_ThisHotkey '`t' A_TimeSincePriorHotkey '`t' A_TimeSinceThisHotkey ' >=? ' UserConfig.HoldCapsLockShowTipsDelay)
		if (A_TimeSinceThisHotkey >= UserConfig.HoldCapsLockShowTipsDelay) {
			if (!UISets.hotTips.isShow) {
				; Console.Debug('-----显示提示-----' A_TickCount - timer)
				; 读取绑定的窗口信息
				bindingKeys := StrSplit(IniRead('winsInfosRecorder.ini', , , ''), '`n')
				; Console.Debug(bindingKeys.Length)
				; 清空原本展示的内容
				UISets.hotTips.ClearTips()
				; tipsMsg := ''
				; 添加新的内容
				for (key in bindingKeys) {
					ahk_exe := IniRead('winsInfosRecorder.ini', key, 'ahk_exe', '未知程序名')
					ahk_id := IniRead('winsInfosRecorder.ini', key, 'ahk_id', '未知程序名')
					path := IniRead('winsInfosRecorder.ini', key, 'path', '')
					; tipsMsg .= key ":`t" ahk_exe "`n"
					oldTitle := IniRead('winsInfosRecorder.ini', key, 'ahk_title', '')
					title := oldTitle
					try {
						hwnd := WinExist(" ahk_id" ahk_id)
						if (!hwnd)
							hwnd := WinExist(oldTitle " ahk_exe" ahk_exe)
						if (hwnd) {
							title := WinGetTitle("ahk_id" hwnd)
						}
					}
					if (!title)
						title := oldTitle
					; 加载程序图标
					iconNumber := UISets.hotTips.LoadIcon(path)
					UISets.hotTips.AddTipItem(iconNumber, title, ahk_exe, key)
				}
				; Console.Debug(tipsMsg)
				UISets.hotTips.Show((key) => (
					BindingWindow.Active(key),
					isDbClick := true
				))

			}
		}
		Sleep(50)
	}

	UISets.hotTips.Hidden()
	KeyWait('CapsLock')
	; Console.Debug('-----隐藏提示-----')
	; 等到CapsLock被松开才切换CapsLock键的按下标识符
	CapsLockHold := false
}

/**
 * 复制
 * @param showTips 显示提示信息
 */
funcLogic_copy(showTips := false) {
	;* ⚠️ 不要再使用 Critical，会导致剪贴板回调无法抢占执行，从而卡死

	if (showTips) {
		;* 监听剪贴板（必须在复制前注册，避免丢事件）
		OnClipboardChange(handle)
	}

	;* 执行复制操作
	SendInput('^c')

	if (!showTips)
		return

	;* 等待剪贴板更新，避免部分程序延迟写入导致监听不到
	ClipWait 0.5

	; 监听剪贴板，进行剪贴板显示
	OnClipboardChange(handle)

	; DateType 参数
	; 0 = 剪贴板当前为空.
	; 1 = 剪贴板包含可以用文本形式表示的内容(包括从资源管理器窗口复制的文件).
	; 2 = 剪贴板包含完全是非文本的内容, 例如图片.
	handle(DataType) {
		; ⚠️ 回调中不要使用 Critical，否则容易造成线程阻塞

		try {
			; 非文本内容直接提示
			if (DataType != 1) {
				; 使用 SetTimer 延迟执行 UI，避免阻塞剪贴板线程
				SetTimer(() => ShowToolTips("已复制非文本内容", 1000, 20), -10)
				return
			}

			; 截取内容的前15个字符作为预览
			content := Trim(A_Clipboard)
			length := StrLen(content)
			preview := SubStr(content, 1, 15)
			lengthPreview := StrLen(preview)
			if (length > lengthPreview) {
				; 计算差值
				diff := length - lengthPreview
				preview .= '……(等' . diff . '个字符)'
			}
			; 超出的长度用……拼接

			; ⚠️ UI 操作不要直接执行，改为异步（避免卡死）
			SetTimer(() => ShowToolTips(preview, 1000, 20), -10)

			; Console.Debug('DataType:' . DataType)
			; ShowToolTips('复制成功！')

		} catch as e {
			Console.Debug(e)
		} finally {
			; 无论是否异常，都必须解绑监听，避免重复触发或泄漏
			OnClipboardChange(handle, 0)
		}
	}

}

; f 复制所选文件路径
funcLogic_copy_selected_paths() {
	;* 防止当前线程被其他线程中断, 或使其能够被中断.
	; Critical "On" ;* ⚠️ 不建议开启，会导致 UI 和剪贴板操作卡顿

	; 获取选中的文件路径
	paths := GetSelectedExplorerItemsPaths()
	if (!paths.Length) {
		;* ⚠️ UI 操作改为异步，避免阻塞线程
		SetTimer(() => ShowToolTips('没有选中文件(文件夹)', , 20), -10)
		return
	}

	output := ''
	showInfo := ''

	index := 1
	for (path in paths) {
		output .= path (index < paths.Length ? '`n' : '')

		; 显示showInfo显示的行数量
		if (index <= 5) {
			showInfo := output
			if (paths.Length - index > 0) {
				showInfo .= "…… (等 " (paths.Length - index) " 条结果)"
			}
		}

		index++
	}

	; Console.Debug('获取路径：`n' output)

	;* ⚠️ 写入剪贴板前建议清空，避免某些程序不触发更新
	A_Clipboard := ''
	A_Clipboard := output

	;* ⚠️ 简单兜底，确保剪贴板写入完成（尤其是大量路径时）
	ClipWait 0.3

	;* ⚠️ UI 操作改为异步，避免潜在卡顿
	SetTimer(() => ShowToolTips('获取路径：`n' showInfo, 1500, 20), -10)
}

; f 粘贴
funcLogic_paste() {
	if (WinActive('ahk_class CabinetWClass')) {
		SendInput('+{Insert}')
	} else {
		SendInput('^v')
	}
}

; f 删除当前行
funcLogic_deleteLine() {
	ClipboardOld := ClipboardAll()
	loop (3) {
		A_Clipboard := ""
		SendInput('^c')
		ClipWait(0.05)
		selText := A_Clipboard
		tmp := Ord(selText)
		; tmp := selText
		if (selText && tmp != 13) {
			SendInput('{Backspace}')
		}
		SendInput('{End}+{Home}')
	}
	SendInput('{Backspace}')
	A_Clipboard := ClipboardOld
}

; f 复制当前行到下一行
funcLogic_copyLineDown() {
	ShowToolTips('复制当前行到下一行')
	tmpClipboard := ClipboardAll()
	A_Clipboard := ""
	SendInput('{home}+{End}^c')
	ClipWait(0.05, 0)
	SendInput('{end}{enter}^v')
	Sleep(50)
	A_Clipboard := tmpClipboard
	return
}

; f 复制当前行到上一行
funcLogic_CopyLineUp() {
	ShowToolTips('复制当前行到上一行')
	tmpClipboard := ClipboardAll()
	A_Clipboard := ""
	SendInput('{Home}+{End}^c')
	ClipWait(0.05, 0)
	SendInput('{up}{end}{enter}^v')
	Sleep(50)
	A_Clipboard := tmpClipboard
	return
}

; f 选择的内容用括号括起来
funcLogic_doubleChar(char1, char2 := "") {
	if (char2 == "") {
		char2 := char1
	}
	charLen := StrLen(char2)
	selText := GetSelText()
	ShowToolTips("替换结果：" . char1 . selText . char2)
	ClipboardOld := ClipboardAll()
	if (selText) {
		A_Clipboard := char1 . selText . char2
		SendInput('^v')
	}
	else {
		A_Clipboard := char1 . char2
		Send('^v')
	}
	Sleep(50)
	A_Clipboard := ClipboardOld
	return
}

; f 选中文字切换为小写
funcLogic_switchSelLowerCase() {
	ClipboardOld := ClipboardAll()
	resText := StrLower(GetSelText())
	if (resText) {
		A_Clipboard := resText
		SendInput('^v')
	} else {
		ShowToolTips('没有选中文本')
	}
	Sleep(50)
	A_Clipboard := ClipboardOld
	return
}

; f 选中文字切换为大写
funcLogic_switchSelUpperCase() {
	ClipboardOld := ClipboardAll()
	resText := StrUpper(GetSelText())
	if (resText) {
		A_Clipboard := resText
		SendInput('^v')
	} else {
		ShowToolTips('没有选中文本')
	}
	Sleep(50)
	A_Clipboard := ClipboardOld
	return
}

; f 置顶 / 解除置顶一个窗口
funcLogic_winPin() {
	hwnd := WinExist('A')                      ;获取当前窗口的HWND
	Console.Debug('当前窗口ahk_id：' hwnd)

	WinSetAlwaysOnTop(-1, 'ahk_id' hwnd)

	OpenExperimentalFunction := IniRead(SettingIniPath, 'General', 'OpenExperimentalFunction', false)
	if (IsAlwaysOnTop(hwnd)) {
		if (OpenExperimentalFunction) {
			AlwaysOnTopControl(hwnd)
		} else {
			ShowToolTips('已置顶当前窗口🔝')
		}
	} else {
		if (!OpenExperimentalFunction) {
			ShowToolTips('已解除当前窗口的置顶状态')
		}
	}
	return
}

; f 系统音量增加
funcLogic_volumeUp() {
	; Critical "On"
	; Console.Debug("增加音量")
	SendInput('{Volume_Up}')
}

; f 系统音量减少
funcLogic_volumeDown() {
	; Critical "On"
	; Console.Debug("降低音量")
	SendInput('{Volume_Down}')
}