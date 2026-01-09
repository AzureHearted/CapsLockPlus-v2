#Requires AutoHotkey v2.0
#Include JSON.ahk

; 防止中文被转义
JSON.EscapeUnicode := false

/**
 * 控制台类
 */
class Console {
	/**
	 * 日志打印
	 * @param {Array} args 要打印的内容
	 */
	static Log(args*) {
		for (arg in args) {
			OutputDebug("[Log] " FormatTime(A_Now, 'yyyy-MM-dd HH:mm:ss') '`n' this._VarToString(arg))
		}
	}

	/**
	 * 调试打印
	 * @param {Array} args 要打印的内容
	 */
	static Debug(args*) {
		for (arg in args) {
			OutputDebug(this._VarToString(arg))
		}
	}

	/**
	 * 打印错误信息
	 * @param {Error} e 错误信息对象
	 */
	static Error(e) {
		this.Debug("`n发生错误：" e.File " (" e.Line "行) `n错误原因：" e.What "`n错误信息：" e.Message)
	}

	/**
	 * 变量转字符串(内部)
	 * @param {Any} value 
	 * @returns {String}
	 */
	static _VarToString(value) {
		try {
			; OutputDebug(Type(value))
			switch (Type(value)) {
				case 'Integer', 'String', 'Float':
					return value
				case 'VarRef': ; 解析引用类型
					return this._VarToString(%value%)
				case 'Func': ; 函数类型的特殊显示
					return "(Func) " . Format('{1}`t', value.Name '()')
				default: ; 其余类型直接转JSON
					return JSON.Dump(value, true)
			}
		} catch as e {
			this.Error(e)
		}
	}
}