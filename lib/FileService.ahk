#Requires AutoHotkey v2.0
#Include Console.ahk
#Include JSON.ahk
#Include StringUtils.ahk

class FileService {
	class ScanOptions {
		IsRecursive := 0
		IncludeDirectories := 0
		IncludeFiles := 1
		IncludeHiddenOrSystem := 0
		FileRegex := ""
		DirectoryRegex := ""
		Progress := ""
	}

	; =========================
	; Scan Entry
	; =========================
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


	; =========================
	; Directory Scan
	; =========================
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


	; =========================
	; File filter
	; =========================
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


	; =========================
	; Directory filter
	; =========================
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


	; =========================
	; Hidden/System check
	; =========================
	static IsHiddenOrSystem(path) {
		try {
			attr := FileGetAttrib(path)
			return InStr(attr, "H") || InStr(attr, "S")
		} catch {
			return false
		}
	}


	; =========================
	; Dedup + Sort
	; =========================
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


	; =========================
	; File ops
	; =========================
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


	; =========================
	; Open path
	; =========================
	static OpenPath(path) {
		if !path
			return
		Run path
	}


	static OpenAndSelect(path) {
		if !path
			return
		Run 'explorer.exe /select,"' path '"'
	}


	; =========================
	; JSON save
	; =========================
	; static SaveAsJson(filePath, data) {
	; 	try {
	; 		SplitPath filePath, , &dir
	; 		if dir && !DirExist(dir)
	; 			DirCreate(dir)

	; 		json := Jxon_Dump(data, 2)

	; 		FileDelete filePath
	; 		FileAppend json, filePath, "UTF-8"
	; 		return true
	; 	} catch {
	; 		return false
	; 	}
	; }


	; =========================
	; Text save
	; =========================
	static SaveText(filePath, content) {
		try {
			SplitPath filePath, , &dir
			if dir && !DirExist(dir)
				DirCreate(dir)

			FileDelete filePath
			FileAppend content, filePath, "UTF-8"
			return true
		} catch {
			return false
		}
	}


	; =========================
	; Helpers (directory listing)
	; =========================
	static DirGetFiles(dir) {
		arr := []
		Loop Files dir "\*", "F"
			arr.Push(A_LoopFileFullPath)
		return arr
	}


	static DirGetFolders(dir) {
		arr := []
		Loop Files dir "\*", "D"
			arr.Push(A_LoopFileFullPath)
		return arr
	}
}