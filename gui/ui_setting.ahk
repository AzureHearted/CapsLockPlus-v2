#Requires AutoHotkey v2.0
#Include <lib_functions>

class UISetting {
	;窗口显示标识符
	isShow := false
	;ini设置文件路径
	iniSettingPath := ""

	; 构造函数
	__New(iniPath) {
		this.iniSettingPath := iniPath
		; 构建界面
		this.gui := Gui("+AlwaysOnTop -DPIScale +ToolWindow", "设置")
		this.gui.SetFont("q5 s10", "Microsoft YaHei")
		this.gui.MarginX := 8
		this.gui.MarginY := 10
		; 开机自启
		this.autoStartCheckBox := this.gui.AddCheckbox("x+m y+m vAutoStart", "开机启动")

		; 按住CapsLock显示提示窗口的触发延时
		this.groupHotTips := this.gui.AddGroupBox("x" this.gui.MarginX " y+m" " r3 w250 ", "提示窗口")

		this.gui.AddText("xp" this.gui.MarginX " yp" 24 " Section", "长按Caps键")
		this.gui.AddEdit("x+m yp-" 4 "  w60")
		this.holdCapsLockShowTipsDelayUpDown := this.gui.AddUpDown("Range100-5000 0x80 vHoldCapsLockShowTipsDelay", 1500)
		this.gui.AddText("x+m yp" 4 " ", "ms后回显提示")

		this.gui.AddText("xs y+m" 10 " ", "不透明度")
		this.hotTipsTransparentSlider := this.gui.AddSlider("x+m yp-" 4 " Range0-255 ToolTip", 200)

		; 按钮
		this.btnSave := this.gui.AddButton("xm y+m", "保存(&S)")
		this.btnSave.OnEvent("Click", (*) => this.Save())
		this.btnClose := this.gui.AddButton("x+m", "关闭")
		this.btnClose.OnEvent("Click", (*) => this.Hidden())

		; 绑定事件
		this.gui.OnEvent("Close", (*) => (this.isShow := false))
		this.gui.OnEvent("Size", (guiObj, MinMax, Width, Height) => this.OnResize(guiObj, MinMax, Width, Height))
	}

	OnResize(guiObj, MinMax, Width, Height) {
		this.gui.GetClientPos(&wx, &wy, &ww, &wh)
		this.btnClose.GetPos(, , &wBtnClose)
		this.btnClose.Move(ww - wBtnClose - this.gui.MarginX)
	}

	; 加载配置
	Load() {
		; 从ini中读取变量
		this.autoStartCheckBox.Value := IniRead(this.iniSettingPath, "General", "AutoStart", 0)
		this.holdCapsLockShowTipsDelayUpDown.Value := IniRead(this.iniSettingPath, "General", "HoldCapsLockShowTipsDelay", 1500)
		this.hotTipsTransparentSlider.Value := IniRead(this.iniSettingPath, "General", "HotTipsTransparent", 200)
	}

	; 显示窗口
	Show() {
		if (this.isShow)
			return
		this.isShow := true

		; 加载配置
		this.Load()

		; 显示窗口
		this.gui.Show()
	}

	; 保存配置
	Save() {
		Console.Debug("设置保存")
		IniWrite(this.autoStartCheckBox.Value, this.iniSettingPath, "General", "AutoStart")
		IniWrite(this.holdCapsLockShowTipsDelayUpDown.Value, this.iniSettingPath, "General", "HoldCapsLockShowTipsDelay")
		IniWrite(this.hotTipsTransparentSlider.Value, this.iniSettingPath, "General", "HotTipsTransparent")
		;! 检测并修复配置生效状态
		CheckAndFixSettingsStatus()
		this.Hidden()
	}

	; 隐藏窗口
	Hidden() {
		WinClose(this.gui)
	}


	; 析构函数
	__Delete() {
		this.gui.Destroy()
	}
}