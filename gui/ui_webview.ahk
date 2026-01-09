#Requires AutoHotkey v2.0
#Include <WebView2/WebView2>

class UIWebView {
	gui := Gui('+AlwaysOnTop +ToolWindow')
	; 窗口显示标识符
	isShow := false
	; 历史路径
	history := ''

	/**
	 * WebView窗口
	 * @param {String} url 要访问的Url
	 * @param {Number} width 窗口宽度
	 * @param {Number} height 窗口高度
	 * @param {Object} objToBeInjected 待注入对象(用于WebView与AHK进行交互)
	 */
	__New(title := '浏览器', url := 'https://www.autohotkey.com/', width := A_ScreenWidth * 0.5, height := A_ScreenHeight * 0.6, objToBeInjected := {}) {
		this.title := title
		this.url := url
		this.width := width
		this.height := height
		; 待注入的对象
		this.objToBeInjected := objToBeInjected
		; WebView2加载器的路径
		; this.WebView2LoaderPath := A_IsCompiled ? A_Temp '\WebView2Loader_' (A_PtrSize * 8) 'bit.dll' : A_LineFile '\..\lib\WebView2\' (A_PtrSize * 8) 'bit\WebView2Loader.dll'
		this.WebView2LoaderPath := A_Temp '\CapsLockPlus v2\WebView2Loader_' (A_PtrSize * 8) 'bit.dll'

		; WebView2相关对象
		this.wvc := {}
		this.wv := {}

		; 绑定事件
		this.gui.OnEvent('Close', (*) => this.Close())
		this.gui.OnEvent('Close', (*) => (this.isShow := false, this.wvc := this.wv := 0))
	}

	; 显示窗口
	Show(url := '') {
		try {
			if (this.isShow)
				return
			this.isShow := true

			; 更新窗口标题
			this.gui.Title := this.title
			; 显示窗口
			this.gui.Show('w' this.width 'h' this.height)
			; 自动获取焦点

			wvc := WebView2.CreateControllerAsync(this.gui.Hwnd, , , , this.WebView2LoaderPath).await2()
			this.wvc := wvc
			wv := wvc.CoreWebView2
			this.wv := wv
			; wvc.DefaultBackgroundColor := 0

			if (!url) {
				url := this.url
			}

			Console.Debug(url ? url : this.history '`t' this.history)
			this.ToNavigate(url ? url : this.history)
			; 使窗口获得焦点
			wvc.MoveFocus(0)
			; 禁止外部文件退拽到WebView窗口
			wvc.AllowExternalDrop := false
			; 注入脚本
			this.InjectionObject()
		} catch as e {
			MsgBox(e.Message "`n" this.WebView2LoaderPath, 'WebView出错')
		}

	}

	; 导航到指定url
	ToNavigate(url := '') {
		if (!url)
			return
		this.wv.Navigate(url)
		this.history := url
	}

	; 隐藏窗口
	Hidden() {
		WinClose(this.gui)
	}

	Close() {
		this.isShow := false
	}

	/**
	 * f 添加对象到WebView环境中
	 * @param {String} name 对象名
	 * @param {Object} obj 对象
	 */
	InjectionObject() {
		this.wv.AddHostObjectToScript('ahk', this.objToBeInjected)
	}

	__Delete() {
		Console.Debug('销毁WebView窗口')
		this.gui.Destroy()
	}
}