#Requires AutoHotkey v2.0

; ? 在系统temp文件夹下创建依赖目录，并释放依赖文件
DirCreate(A_Temp '\CapsLockPlus v2')
try {
	FileInstall('lib/WebView2/32bit/WebView2Loader.dll', A_Temp '\CapsLockPlus v2\WebView2Loader_32bit.dll', 1)
	FileInstall('lib/WebView2/64bit/WebView2Loader.dll', A_Temp '\CapsLockPlus v2\WebView2Loader_64bit.dll', 1)
	FileInstall('tools/WindowSpy.exe', A_Temp '\CapsLockPlus v2\WindowSpy.exe', 1)
	FileInstall('res/keysMap.html', A_Temp '\CapsLockPlus v2\keysMap.html', 1)
	FileInstall('res/CapsLockPlusIcon.ico', A_Temp '\CapsLockPlus v2\CapsLockPlusIcon.ico', 1)
	FileInstall('res/cancelAlwaysOnTop.png', A_Temp '\CapsLockPlus v2\cancelAlwaysOnTop.png', 1)
} catch as ex {
	Console.Debug('释放依赖过程中发生意外错误`n' . ex.Message)
}

#Include <Console>
#Include <Array>
#Include <StringUtils>
#Include <lib_functions>
#Include <lib_keysFunLogic>
#Include <lib_userHotString>
#Include <lib_userTips>
#Include <lib_bindingWindow>
#Include <KeysMap>
#Include <CapsHotkey>
#Include ../user_keys.ahk ;* 导入用户自定义热键


#Include ../gui/ui_setting.ahk
#Include ../gui/ui_webview.ahk
#Include ../tools/ReNamer.ahk

; ? 忽略DPI缩放(必须在创建GUI之前调用)
if (GetWindowsVersion().Major >= 10) {
	; Windows 10+ 的上效果最佳
	DllCall("User32\SetThreadDpiAwarenessContext", "UInt", -5)
} else {
	; Windows 10 以下效果最佳
	DllCall("User32\SetThreadDpiAwarenessContext", "UInt", -1)
}

; A_MaxHotkeysPerInterval和A_HotkeyInterval变量控制热键激活的速率, 超过此速率将显示警告对话框.
A_MaxHotkeysPerInterval := 500
A_HotkeyInterval := 0

; ? 确保以管理员身份运行
full_command_line := DllCall("GetCommandLine", "str")
if ( not (A_IsAdmin or RegExMatch(full_command_line, " /restart(?!\S)"))) {
	Console.Debug(full_command_line)
	try
	{

		msg := '检测到脚本并未以管理员身份启动，即将以管理员身份重新启动~'
		Console.Debug(msg)
		ShowToolTips(msg)
		; Run('*RunAs "' A_ScriptFullPath '"')
		if A_IsCompiled
			Run '*RunAs "' A_ScriptFullPath '" /restart'
		else
			Run '*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"'
		ExitApp()
	}
	catch as e {
		MsgBox ("无法以管理员身份运行脚本。错误信息：" e.Message)
		ExitApp()
	}
}

; s 全局变量
; 用户设置的ini路径
global SettingIniPath := 'settings.ini'
; Caps 开关标识符
global CapsLockOpen := GetKeyState('CapsLock', 'T') ; 记录初始CapsLock按键状态
; Caps 按住时候的标识符
global CapsLockHold := false
; 用户热字符串控制器
global UserHotStr := UserHotString(SettingIniPath)
; 用户配置
global UserConfig := {
	HoldCapsLockShowTipsDelay: 2000, ; 提示窗口显示延时（ms,100 ~ 5000）
	HotTipsTransparent: 200, ; 提示窗口的透明度（0 ~ 255）
	URLDefault: 'http://wdxt.taibiao.com.cn/'
}

; s UI集合
global UISets := {
	; /** @type {UISetting} */
	setting: UISetting('settings.ini'), ; 设置窗口
	; hotTips: UITips('已绑定的窗口`t', ["进程", "按键"]), ; Caps按住一段时间后的提示窗口及内容
	hotTips: UserTips(), ; Caps按住一段时间后的提示窗口及内容
	keysMap: UIWebView('键盘映射', A_IsCompiled ? A_Temp '\CapsLockPlus v2\keysMap.html' : 'http://localhost:5173/', 1160, 380, {
		debug: (res) => Console.Debug(res)
	}),
	batchRename: BatchReName()
}


; s 绑定默认的CapsLook热键
/** @type {CapsHotkey} */
CapsLookPlus := CapsHotkey()


; f 初始化
Init() {
	;* 设置启动脚本时默认CapsLock状态关闭
	SetCapsLockState("Off")

	/** 阻止默认CapsLock事件 */
	Hotkey('*CapsLock', (*) => false)

	; 按下 CapsLock 后触发 CapsLock 按下事件
	Hotkey('CapsLock', (*) => funcLogic_capsHold())

	; 通过 Shift + CapsLock 触发切换CapsLock
	Hotkey('+CapsLock', (*) => funcLogic_capsSwitch())

	;* 装载图标
	LoadIcon()

	;* 初始化配置
	InitSetting()

	;* 检测并修复配置生效状态
	CheckAndFixSettingsStatus()

	;* 开启用户热字符串
	UserHotStr.Enable()

	;* 托盘菜单
	InitTrayMenu()

	;* 注册鼠标全局热键
	RegisterMouseGlobalHotkeys()

	CapsLookPlus.Init()

	;* 注册默认CapsLook热键
	RegisterCapsLookDefaultHotkeys()

	;* 注册用户CaspLook热键
	RegisterUserCapsLookHotkeys()

	ShowToolTips('CapsLock Plus v2 已启动！')
}

;! 初始化设置
InitSetting() {
	/** 判断配置文件是否存在 */
	; 如果没有检测到settings.ini则认为是首次启动
	if (!FileExist(SettingIniPath)) {
		; 首次启动写入配置文件
		; 开机自启
		IniWrite(0, SettingIniPath, "General", 'AutoStart')
		; 按住CapsLock后多少ms显示Tips (默认1500ms)
		IniWrite(1500, SettingIniPath, "General", 'HoldCapsLockShowTipsDelay')
		; 提示窗透明度
		IniWrite(200, SettingIniPath, "General", 'HotTipsTransparent')
		; Everything相关
		IniWrite("C:\Program Files\Everything\Everything.exe", SettingIniPath, "Everything", 'Path')
		; 实验性功能
		IniWrite(false, SettingIniPath, "General", 'OpenExperimentalFunction')
		ShowToolTips('首次启动~')
	}

	;* 读取配置
	LoadConfig()
}

;! 装载图标
LoadIcon() {
	CapsLockPlusIcon := A_Temp '\CapsLockPlus v2\CapsLockPlusIcon.ico'
	if FileExist(CapsLockPlusIcon) {
		TraySetIcon(CapsLockPlusIcon, 1)
	}
}

;! 读取配置
LoadConfig() {
	UserConfig.HoldCapsLockShowTipsDelay := IniRead(SettingIniPath, 'General', 'HoldCapsLockShowTipsDelay', 1500)
}

;* 检测并修复配置生效状态
CheckAndFixSettingsStatus() {
	;? 判断是否开机自启动
	isAutoStart := IniRead(SettingIniPath, 'General', 'AutoStart', false)
	;? 设置当前用户开机启动
	autostartLnk := A_Startup . "\CapsLockPlus v2.lnk"
	;? 这是整个计算机开机启动
	; autostartLnk := A_StartupCommon . "\CapsLockPlus v2.lnk"

	;? 判断是否开机启动
	if (isAutoStart) {
		; 设置开机启动
		if (FileExist(autostartLnk))
		{
			FileGetShortcut(autostartLnk, &lnkTarget)
			if (lnkTarget != A_ScriptFullPath)
				FileCreateShortcut(A_ScriptFullPath, autostartLnk, A_WorkingDir)
		} else {
			FileCreateShortcut(A_ScriptFullPath, autostartLnk, A_WorkingDir)
		}
	} else {
		; 如果不设置则删除开机启动的快捷方式
		if (FileExist(autostartLnk))
		{
			FileDelete(autostartLnk)
		}
	}

	;? 从settings.ini中更新 HoldCapsLockShowTipsDelay
	UserConfig.HoldCapsLockShowTipsDelay := IniRead(SettingIniPath, 'General', 'HoldCapsLockShowTipsDelay', 1500)
	UserConfig.HotTipsTransparent := IniRead(SettingIniPath, 'General', 'HotTipsTransparent', 200)
	UISets.hotTips.transparent := UserConfig.HotTipsTransparent
}

;* 初始化托盘菜单
InitTrayMenu() {
	;* 托盘菜单
	; TrayMenu := A_TrayMenu
}

;* 注册鼠标全局事件
RegisterMouseGlobalHotkeys() {
	;! 鼠标事件绑定
	Hotkey('WheelDown', MouseWheelHandle)
	Hotkey('WheelUp', MouseWheelHandle)

	/**
	 * 鼠标滚动事件执行器
	 * @param {'WheelDown'|'WheelUp'} HotkeyName 触发的热键
	 */
	MouseWheelHandle(HotkeyName) {
		try {
			MouseGetPos(&mx, &my)
			hwnd := WinActive('A')
			if (!hwnd)
				return
			WinGetPos(&wx, &wy, &ww, &wh, 'ahk_id' hwnd)
			;? 计算当前鼠标相对窗口的位置
			mxc := mx + wx
			myc := my + wy

			; Console.Debug('mx:' mx ',my:' my '`twx:' wx ',wy:' wy ',ww:' ww ',wh:' wh '`tmxc:' mxc ',myc:' myc '`thWnd:' hWnd)

			;? 判断鼠标是否处于窗口顶部
			if (myc <= 0) {
				switch (HotkeyName) {
					case 'WheelUp': funcLogic_volumeUp()
					case 'WheelDown': funcLogic_volumeDown()
				}
			} else {
				; 判断鼠标是否在窗口的前 20 像素内（窗口区域顶部）
				SendInput(Format('{{1}}', HotkeyName))
			}
		} catch as e {
			Console.Error(e)
			SendInput(Format('{{1}}', HotkeyName))
		}
	}
}

;* 注册CapsLook的默认热键
RegisterCapsLookDefaultHotkeys() {
	global CapsLookPlus
	; 向⬅️删除一个字符
	CapsLookPlus.AddHotkey("$A", "{Backspace}")
	; 删除光标⬅️边至行首
	CapsLookPlus.AddHotkey("$+A", "+{Home}{Backspace}")
	; 向➡️删除一个字符
	CapsLookPlus.AddHotkey("$S", "{Delete}")
	; 删除光标右边至行末
	CapsLookPlus.AddHotkey("$+S", "+{End}{Backspace}")

	; Win + V (系统剪贴板)
	CapsLookPlus.AddHotkey("$B", "#{v}")
	; 复制
	CapsLookPlus.AddHotkey("$C", (k) => funcLogic_copy(true))
	; 粘贴
	CapsLookPlus.AddHotkey("$V", (k) => funcLogic_paste())
	; 复制所选文件路径
	CapsLookPlus.AddHotkey("$!C", (k) => funcLogic_copy_selected_paths())

	; Ctrl + S (保存)
	CapsLookPlus.AddHotkey("$E", "^{s}")
	; Ctrl + F (🔍搜索)
	CapsLookPlus.AddHotkey("$F", "^{f}")
	; 菜单键
	CapsLookPlus.AddHotkey("$G", "{AppsKey}")

	; ⬅️跳词
	CapsLookPlus.AddHotkey("$H", "^{Left}")
	; ⬅️跳词选择
	CapsLookPlus.AddHotkey("$!H", "^+{Left}")
	; ⬅️跳词删除
	CapsLookPlus.AddHotkey("$!A", "^{Backspace}")

	; ➡️跳词
	CapsLookPlus.AddHotkey("$;", "^{Right}")
	; ➡️跳词选择
	CapsLookPlus.AddHotkey("$!;", "^+{Right}")
	; ➡️跳词删除
	CapsLookPlus.AddHotkey("$!S", "^{Delete}")

	; 方向键映射⬆️
	CapsLookPlus.AddHotkey("$I", "{UP}")
	; 向⬆️选择
	CapsLookPlus.AddHotkey("$!I", "+{UP}")
	; 向⬆️翻页
	CapsLookPlus.AddHotkey("$+I", "{PgUp}")
	; 方向键映射⬅️
	CapsLookPlus.AddHotkey("$J", "{Left}")
	; 向⬅️选择
	CapsLookPlus.AddHotkey("$!J", "+{Left}")
	; 方向键映射⬇️
	CapsLookPlus.AddHotkey("$K", "{Down}")
	; 向⬇️选择
	CapsLookPlus.AddHotkey("$!K", "+{Down}")
	; 向⬇️翻页
	CapsLookPlus.AddHotkey("$+K", "{PgDn}")
	; 方向键映射➡️
	CapsLookPlus.AddHotkey("$L", "{Right}")
	; 向➡️选择
	CapsLookPlus.AddHotkey("$!L", "+{Right}")

	; 删除当前行
	CapsLookPlus.AddHotkey("$D", (k) => funcLogic_deleteLine())

	; 向⬆️另起一行
	CapsLookPlus.AddHotkey("$Enter", "{Up}{End}{Enter}")
	; 向⬇️另起一行
	CapsLookPlus.AddHotkey("$!Enter", "{End}{Enter}")

	; 复制当前行到下一行
	CapsLookPlus.AddHotkey("$M", (k) => (funcLogic_copyLineDown(), KeyWait('M')))
	; 复制当前行到上一行
	CapsLookPlus.AddHotkey("$N", (k) => (funcLogic_CopyLineUp(), KeyWait('M')))

	; 光标定位到行首
	CapsLookPlus.AddHotkey("$U", "{Home}")
	; 从当前光标选至行首
	CapsLookPlus.AddHotkey("$!U", "+{Home}")
	; 定位到文档开头
	CapsLookPlus.AddHotkey("$+U", "^{Home}")

	; 光标定位到行尾
	CapsLookPlus.AddHotkey("$O", "{End}")
	; 从当前光标选至行末
	CapsLookPlus.AddHotkey("$!O", "+{End}")
	; 定位到文档结尾
	CapsLookPlus.AddHotkey("$+O", "^{End}")

	; Esc
	CapsLookPlus.AddHotkey("$P", "{Escape}")
	; Tab键
	CapsLookPlus.AddHotkey("$Space", "{Tab}")

	; 注释当前行
	CapsLookPlus.AddHotkey("$R", "^/")

	; 剪切 Ctrl + x
	CapsLookPlus.AddHotkey("$X", "^{x}")
	; 还原 Ctrl + y
	CapsLookPlus.AddHotkey("$Y", "^{y}")
	; 撤销 Ctrl + z0
	CapsLookPlus.AddHotkey("$Z", "^{z}")

	; Ctrl + Tab切换标签页
	CapsLookPlus.AddHotkey("$+J", "^{Tab}")
	; Ctrl + Shift + Tab切换标签页
	CapsLookPlus.AddHotkey("$+L", "^+{Tab}")

	; 关闭标签页 Ctrl + w
	CapsLookPlus.AddHotkey("$W", "^{w}")
	; Alt + F4 关闭软件
	CapsLookPlus.AddHotkey("$!W", "!{F4}")

	; 置顶 / 解除置顶一个窗口
	CapsLookPlus.AddHotkey("$F1", (k) => funcLogic_winPin())
	; 呼出批量重命名窗口
	CapsLookPlus.AddHotkey("$F2", (k) => UISets.BatchReName.Show())
	/** 打开窗口检查器 */
	CapsLookPlus.AddHotkey("$F9", (k) => Run(A_Temp '\CapsLockPlus v2\WindowSpy.exe'))
	/** WebView2浏览器 */
	CapsLookPlus.AddHotkey("$F10", (k) => UISets.keysMap.Show())
	; 重载脚本
	CapsLookPlus.AddHotkey("$F11", (k) => Reload())
	/** 设置窗口 */
	CapsLookPlus.AddHotkey("$F12", (k) => UISets.setting.Show())

	; 窗口绑定相关
	; 激活
	CapsLookPlus.AddHotkey("$``", (k) => BindingWindow.Active('``'))
	CapsLookPlus.AddHotkey("$1", (k) => BindingWindow.Active('1'))
	CapsLookPlus.AddHotkey("$2", (k) => BindingWindow.Active('2'))
	CapsLookPlus.AddHotkey("$3", (k) => BindingWindow.Active('3'))
	CapsLookPlus.AddHotkey("$4", (k) => BindingWindow.Active('4'))
	CapsLookPlus.AddHotkey("$5", (k) => BindingWindow.Active('5'))
	CapsLookPlus.AddHotkey("$6", (k) => BindingWindow.Active('6'))
	CapsLookPlus.AddHotkey("$7", (k) => BindingWindow.Active('7'))
	CapsLookPlus.AddHotkey("$8", (k) => BindingWindow.Active('8'))
	; 绑定
	CapsLookPlus.AddHotkey("$!``", (k) => BindingWindow.Binding('``'))
	CapsLookPlus.AddHotkey("$!1", (k) => BindingWindow.Binding('1'))
	CapsLookPlus.AddHotkey("$!2", (k) => BindingWindow.Binding('2'))
	CapsLookPlus.AddHotkey("$!3", (k) => BindingWindow.Binding('3'))
	CapsLookPlus.AddHotkey("$!4", (k) => BindingWindow.Binding('4'))
	CapsLookPlus.AddHotkey("$!5", (k) => BindingWindow.Binding('5'))
	CapsLookPlus.AddHotkey("$!6", (k) => BindingWindow.Binding('6'))
	CapsLookPlus.AddHotkey("$!7", (k) => BindingWindow.Binding('7'))
	CapsLookPlus.AddHotkey("$!8", (k) => BindingWindow.Binding('8'))

	; 用()包裹选中内容
	CapsLookPlus.AddHotkey("$9", (k) => funcLogic_doubleChar("(", ")"))
	; 用中文圆括号包裹选中内容
	CapsLookPlus.AddHotkey("$!9", (k) => funcLogic_doubleChar("（", "）"))
	; 用{}包裹选中内容
	CapsLookPlus.AddHotkey("$[", (k) => funcLogic_doubleChar("{", "}"))
	; 用[]包裹选中内容
	CapsLookPlus.AddHotkey("$]", (k) => funcLogic_doubleChar("[", "]"))
	; 用【】包裹选中内容
	CapsLookPlus.AddHotkey("$!]", (k) => funcLogic_doubleChar("【", "】"))
	; 用""包裹选中内容
	CapsLookPlus.AddHotkey("$'", (k) => funcLogic_doubleChar('"'))
	; 用 “” 包裹选中内容
	CapsLookPlus.AddHotkey("$!'", (k) => funcLogic_doubleChar("“", "”"))
	; 用<>包裹选中内容
	CapsLookPlus.AddHotkey("$,", (k) => funcLogic_doubleChar("<", ">"))
	; 用《》包裹选中内容
	CapsLookPlus.AddHotkey("$!,", (k) => funcLogic_doubleChar("《", ">"))


	; 将选中的英文转为小写
	CapsLookPlus.AddHotkey("$!M", (k) => funcLogic_switchSelLowerCase())
	; 将选中的英文转为大写
	CapsLookPlus.AddHotkey("$!N", (k) => funcLogic_switchSelUpperCase())

	; 音量增加
	CapsLookPlus.AddHotkey("$=", (k) => funcLogic_volumeUp())
	CapsLookPlus.AddHotkey("$WheelUp", (k) => funcLogic_volumeUp())
	; 音量降低
	CapsLookPlus.AddHotkey("$-", (k) => funcLogic_volumeDown())
	CapsLookPlus.AddHotkey("$WheelDown", (k) => funcLogic_volumeDown())


	; 呼出Quicker搜索框，并填入选中内容(如果有)
	CapsLookPlus.AddHotkey("$Q", (k) => HandleCallQuicker())
	HandleCallQuicker() {
		id := WinExist('Quicker搜索')
		Run("quicker:search:")
		if (!id) {
			hwnd := WinWait('Quicker搜索')
			WinActivate('ahk_id' hwnd)
			; Console.Debug('已聚焦')
		}
	}

	; todo 打开Everything并🔍搜索选中内容
	CapsLookPlus.AddHotkey("$!F", (k) => HandelCallEverything())
	HandelCallEverything() {
		; 获取选中文本
		text := GetSelText()
		; 读取ini中记录的Everything路径
		pathEverythingExe := IniRead('setting.ini', 'Everything', 'path', "C:\Program Files\Everything\Everything.exe")

		if (!FileExist(pathEverythingExe)) {
			; 如果默认Everything路径不存在，则查看进程中是否有Everything进程
			pid := ProcessExist('Everything.exe')
			if (!pid) {
				; 没有找到Everything进程则提示用户
				ShowToolTips('请确保Everything在后台运行', , 20)
				return
			}
			; 找到Everything进程后更新Everything进程路径
			pathEverythingExe := ProcessGetPath('Everything.exe')
			; 更新配置文件中记录的Everything路径
			IniWrite(pathEverythingExe, 'setting.ini', 'Everything', 'path')
		}
		; 通过命令行调用Everything搜索
		if (id := WinExist("ahk_exe Everything.exe")) {
			WinActivate("ahk_exe Everything.exe")
			ControlSetText(text, "Edit1")
		} else {
			Run(pathEverythingExe ' -s "' text '"')
			hwnd := WinWait('ahk_class EVERYTHING')
			WinActivate('ahk_id' hwnd)
		}
	}

	; office 等软件的带样式粘贴 Ctrl + Alt + V
	CapsLookPlus.AddHotkey("$!V", (k) => HandlePasteByOffice())
	HandlePasteByOffice() {
		if (WinActive('ahk_exe EXCEL.EXE') || WinActive('ahk_exe wps.exe') || WinActive('ahk_class XLMAIN')) {
			; Ctrl + Alt + V
			SendInput('^!v')
		}
	}

	; Ctrl + Win + Right 切换下一个虚拟窗口
	CapsLookPlus.AddHotkey("$+E", "^#{Right}")
	; Ctrl + Win + left 切换上一个虚拟窗口
	CapsLookPlus.AddHotkey("$+Q", "^#{Left}")
	; Ctrl + Win + D 创建虚拟窗口
	CapsLookPlus.AddHotkey("$+R", "^#{d}")
	; Ctrl + Win + F4 关闭当前虚拟窗口
	CapsLookPlus.AddHotkey("$+W", "^#{F4}")


	; 鼠标左键 (禁用空的事件还原默认事件)
	CapsLookPlus.DisableHotkey("$LButton")
	CapsLookPlus.DisableHotkey("$MButton")
	CapsLookPlus.DisableHotkey("$RButton")
	CapsLookPlus.DisableHotkey("$!LButton")
	CapsLookPlus.DisableHotkey("$!MButton")
	CapsLookPlus.DisableHotkey("$!RButton")
	CapsLookPlus.DisableHotkey("$+LButton")
	CapsLookPlus.DisableHotkey("$+MButton")
	CapsLookPlus.DisableHotkey("$+RButton")
	CapsLookPlus.DisableHotkey("$^LButton")
	CapsLookPlus.DisableHotkey("$^MButton")
	CapsLookPlus.DisableHotkey("$^RButton")
}