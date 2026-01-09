#Requires AutoHotkey v2.0
#Include <lib_functions>
/**
 * ! 置顶控制
 */
class AlwaysOnTopControl {
	; 图标路径
	picUrl := A_Temp '\CapsLockPlus v2\cancelAlwaysOnTop.png'
	; 偏移量
	scale := A_ScreenDPI / 96 ; 获取缩放比例
	size := 24  ;图标尺寸
	offsetX := -180
	offsetY := 6

	removeFlag := false

	__New(targetId) {
		this.tid := targetId
		this.gui := Gui('+ToolWindow -Caption -DPIScale' ' +Owner' targetId)
		this.gui.MarginX := 0
		this.gui.MarginY := 0


		this.pic := this.gui.AddPicture('w' this.size ' h-1', this.picUrl)
		this.pic.OnEvent('Click', (*) => this.HandleClick())


		WinActive('ahk_id' this.tid)
		this.GetParentPos(&px, &py, &pw, &ph)

		this.gui.Show('x' (px + pw + this.offsetX) ' y' (py + this.offsetY))
		this.gui.BackColor := "ffffff"
		WinSetTransColor("ffffff", this.gui)

		; 类中的回调函数使用方法
		this.timerFun := ObjBindMethod(this, 'Hook')
		SetTimer(this.timerFun, 10, 100000000)
	}

	GetParentPos(&px := 0, &py := 0, &pw := 0, &ph := 0) {
		WinGetPos(&px, &py, &pw, &ph, 'ahk_id' this.tid)
	}

	HandleClick(*) {
		SetTimer(this.timerFun, 0)
		WinSetAlwaysOnTop(false, 'ahk_id' this.tid)
		Console.Debug('取消窗口置顶')
		this.Remove()
		return
	}

	Hook() {
		; * 停止条件：目标窗口不存在 | removeFlag == true
		if (!IsAlwaysOnTop(this.tid) || !WinExist('ahk_id' this.tid) || this.removeFlag)
		{
			this.Remove()
			Console.Debug('窗口被关闭了')
			SetTimer(this.timerFun, 0)
		}

		this.GetParentPos(&px, &py, &pw, &ph)
		x := px + pw + this.offsetX
		y := py + this.offsetY
		try this.gui.Move(x, y)
	}

	Remove() {
		SetTimer(this.timerFun, 0)
		this.pic.OnEvent('Click', (*) => this.HandleClick(), 0)
		this.removeFlag := true
		this.__Delete()
	}

	__Delete() {
		this.gui.Destroy()
		this.gui := ""
		Console.Debug('释放AlwaysOnTopControl')
	}
}