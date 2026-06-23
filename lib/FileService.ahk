#Requires AutoHotkey v2.0
#Include Console.ahk
#Include JSON.ahk
#Include StringUtils.ahk
#Include JSON.ahk

; 文件系统服务
class FileService {
	; 扫描配置项
	class ScanOptions {
		; 是否深度递归
		IsRecursive := 0
		; 包含目录
		IncludeDirectories := 0
		; 包含文件夹
		IncludeFiles := 1
		; 包含隐藏或系统文件
		IncludeHiddenOrSystem := 0
		; 文件过滤的正则表达式
		FileRegex := ""
		; 目录过滤的正则表达
		DirectoryRegex := ""
		; 进度
		Progress := ""
	}

	/**
	 * 同步方式扫描路径
	 * @param paths 扫描路径
	 * @param options 选项
	 * @returns {Array} 扫描结果
	 */
	static ScanPathsAsync(paths, options) {
		results := []
		processed := 0
		total := paths.Length

		for path in paths {

			if FileExist(path) && !DirExist(path) {
				this.TryAddFile(path, results, options)

			} else if DirExist(path) {
				this.TryAddDirectory(path, results, options)
				this.ScanDirectory(path, results, options)
			}

			processed++

			if options.Progress && total > 0
				options.Progress.Call(Round(processed * 100 / total))
		}

		return this.UniqueSort(results)
	}


	/**
	 * 扫描目录
	 * @param dir 目录
	 * @param results 扫描结果 (外部传入)
	 * @param options 选项
	 */
	static ScanDirectory(dir, results, options) {
		try {

			if options.IncludeFiles {
				for file in this.DirGetFiles(dir)
					this.TryAddFile(file, results, options)
			}

			for subDir in this.DirGetFolders(dir) {

				this.TryAddDirectory(subDir, results, options)

				if options.IsRecursive
					this.ScanDirectory(subDir, results, options)
			}

		} catch {
			; ignore access denied
		}
	}


	/**
	 * 尝试添加文件 (根据选项过滤)
	 * @param file 文件路径
	 * @param results 扫描结果 (外部传入)
	 * @param options 选项
	 */
	static TryAddFile(file, results, options) {

		if !options.IncludeFiles
			return

		if !options.IncludeHiddenOrSystem && this.IsHiddenOrSystem(file)
			return

		if !options.FileRegex {
			results.Push(file)
			return
		}

		SplitPath(file, &fileName)

		if fileName ~= "i)" options.FileRegex
			results.Push(file)
	}


	/**
	 * 尝试添加文件夹 (根据选项过滤)
	 * @param dir 文件夹路径
	 * @param results 扫描结果 (外部传入)
	 * @param options 选项
	 */
	static TryAddDirectory(dir, results, options) {

		if !options.IncludeDirectories
			return

		if !options.IncludeHiddenOrSystem && this.IsHiddenOrSystem(dir)
			return

		if !options.DirectoryRegex {
			results.Push(dir)
			return
		}

		SplitPath(file, &fileName)

		if fileName ~= "i)" options.DirectoryRegex
			results.Push(dir)
	}


	/**
	 * Hidden/System 检查
	 * @param path 要检查的路径
	 * @returns {Integer} 路径是否具有 H 或 S 属性
	 */
	static IsHiddenOrSystem(path) {
		try {
			attr := FileGetAttrib(path)
			return InStr(attr, "H") || InStr(attr, "S")
		} catch {
			return false
		}
	}

	/**
	 * 判断一个路径是否是目录
	 * @param path 路径
	 */
	static IsDirectory(path) {
		attrib := DirExist(path)
		return attrib ~= "[D]"
	}


	/**
	 * 去重 + 排序
	 * @param arr 要排序的数组
	 * @returns 排序结果
	 */
	static UniqueSort(arr) {
		_map := Map()

		for v in arr
			_map[v] := 1

		arr := []

		for k in _map
			arr.Push(k)

		this.SortArray(arr)
		return arr
	}

	/**
	 * 排序数组 (辅助函数)
	 * @param arr 数组
	 */
	static SortArray(arr) {

		len := arr.Length

		Loop len - 1 {
			i := A_Index

			Loop len - i {
				j := A_Index

				if (StrCompare(arr[j], arr[j + 1]) > 0) {
					tmp := arr[j]
					arr[j] := arr[j + 1]
					arr[j + 1] := tmp
				}
			}
		}
	}


	/**
	 * 文件移动
	 * @param source 源路径
	 * @param target 目标路径
	 * @returns {Integer} 是否成功
	 */
	static MoveFile(source, target) {
		try {
			if !FileExist(source)
				return false

			if FileExist(target)
				return false

			FileMove(source, target)
			return true
		} catch {
			return false
		}
	}


	/**
	 * 文件杀出
	 * @param path 路径
	 * @returns {Integer} 是否成功
	 */
	static DeleteFile(path) {
		try {
			if !FileExist(path)
				return true

			FileDelete(path)
			return true
		} catch {
			return false
		}
	}


	/**
	 * 打开路径
	 * @param path 路径
	 */
	static OpenPath(path) {
		if !path
			return
		Run path
	}


	/**
	 * 在文件资源管理器中定位路径
	 * @param path 路径
	 */
	static OpenAndSelect(path) {
		if !path
			return
		Run 'explorer.exe /select,"' path '"'
	}


	/**
	 * 保存为 Json 格式
	 * @param filePath 保存路径
	 * @param data json 数据
	 * @returns {Integer} 是否成功
	 */
	static SaveAsJson(filePath, data) {
		try {
			SplitPath(filePath, , &dir)
			if (dir && !DirExist(dir))
				DirCreate(dir)

			_json := JSON.Stringify(data)

			FileDelete(filePath)
			FileAppend(_json, filePath, "UTF-8")
			return true
		} catch {
			return false
		}
	}


	/**
	 * 保存文本内容到文件
	 * @param filePath 保存路径
	 * @param content 文本内容
	 * @returns {Integer} 是否成功
	 */
	static SaveText(filePath, content) {
		try {
			SplitPath(filePath, , &dir)
			if (dir && !DirExist(dir))
				DirCreate(dir)

			FileDelete(filePath)
			FileAppend(content, filePath, "UTF-8")
			return true
		} catch {
			return false
		}
	}


	/**
	 * 获取目录下的文件
	 * @param dir 目录路径
	 * @returns {Array} 获取结果
	 */
	static DirGetFiles(dir) {
		arr := []
		Loop Files dir "\*", "F"
			arr.Push(A_LoopFileFullPath)
		return arr
	}


	/**
	 * 获取目录下的文件夹
	 * @param dir 目录路径
	 * @returns {Array} 获取结果
	 */
	static DirGetFolders(dir) {
		arr := []
		Loop Files dir "\*", "D"
			arr.Push(A_LoopFileFullPath)
		return arr
	}
}