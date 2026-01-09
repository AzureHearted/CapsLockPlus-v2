#Requires AutoHotkey v2.0
#Include Console.ahk

; String工具扩展
class StringUtils {

	class ExtraOptions extends Object {
		/** 忽略大小 */
		ignoreCase := false
		/** 全字匹配 (使用 \b 单词边界) */
		isExactMatch := false
	}

	/**
	 * f 插入字符串(基于索引)
	 * @param {String} original - 原字符串
	 * @param {String} insert - 要插入的内容
	 * @param {Integer} index - 要插入的位置 (正数，且输入0会自动变成1，注意：AHK v2 索引从 1 开始)
	 * @param {Integer} reverse - 从右到左
	 * @returns {String} 插入后的新字符串
	 */
	static InsertByIndex(original, insert, index, reverse := false) {
		; AHK v2 的 SubStr() 索引从 1 开始
		; 如果您希望像 JS/TS 那样索引从 0 开始，需要在使用前将 index + 1

		OriginalLen := StrLen(original)

		; --- 1. 索引校验和标准化 ---
		; 确保 index 是正数，如果 <= 0 则强制为 1 (AHK 1-based index)
		index := index > 0 ? index : 1

		; --- 2. 确定实际插入位置 (1-based AHK index) ---

		if (!reverse) {
			; 从左到右 (L-R)
			; index 就是插入点在字符串中的位置 (例如 index=1 是开头，index=OriginalLen+1 是末尾)
			InsertPos := index

			; 边界检查：确保 InsertPos 不超过字符串长度 + 1
			if (InsertPos > OriginalLen + 1) {
				InsertPos := OriginalLen + 1
			}

		} else {
			; 从右到左 (R-L)
			; R-L 索引 1 对应 L-R 索引 OriginalLen
			; R-L 索引 index 对应 L-R 索引 (OriginalLen - index + 1)

			InsertPos := OriginalLen - index + 2
			; 注意：+2 是因为我们希望在 R-L 索引 1 (最后一个字符) 之后插入。
			; 如果 index=1，InsertPos=OriginalLen+1 (末尾)

			; 边界检查：确保 InsertPos 不小于 1
			if (InsertPos < 1) {
				InsertPos := 1
			}
		}

		; --- 3. 使用 SubStr 进行分割和拼接 ---

		; PartBefore: 从 1 开始，长度为 InsertPos - 1
		PartBefore := SubStr(original, 1, InsertPos - 1)

		; PartAfter: 从 InsertPos 开始，到末尾
		PartAfter := SubStr(original, InsertPos)

		return PartBefore . insert . PartAfter
	}


	/**
	 * f 插入字符串（基于匹配结果）
	 * @param {String} original - 原始字符串
	 * @param {String} insert - 要插入的内容
	 * @param {String} match - 要匹配的字符串（将自动转义正则特殊字符）
	 * @param {"Before"|"After"} position - 插入位置，"Before" 或 "After"
	 * @param {StringUtils.ExtraOptions} extraOptions - 额外选项，包含 `ignoreCase`(忽略大小写) 和 `isExactMatch`(全字匹配) 的对象
	 * @returns - 返回修改后的字符串
	 */
	static InsertByMatch(original, insert, match, position, extraOptions := {}) {

		; --- 1. 处理选项和默认值 ---
		; AHK V2 的 ?? 运算符 (Null Coalescing)
		ignoreCase := extraOptions.HasOwnProp('ignoreCase') ? extraOptions.ignoreCase : false
		isExactMatch := extraOptions.HasOwnProp('isExactMatch') ? extraOptions.isExactMatch : false

		; --- 2. 构建正则表达式 Pattern ---
		Pattern := ""

		; 步骤 A: 使用 \Q...\E 确保 match 字符串中的所有内容都被视为字面量
		; AHK v2 的字符串连接符是 .
		EscapedMatch := "\Q" . match . "\E"

		; 步骤 B: 应用全词匹配 (\b)
		if (isExactMatch) {
			Pattern := "\b(" . EscapedMatch . ")\b"
		} else {
			Pattern := "(" . EscapedMatch . ")"
		}

		; 步骤 C: 应用忽略大小写选项 (i)
		if (ignoreCase) {
			Pattern := "i)" . Pattern  ; i) 选项放在最前面
		}

		; --- 3. 构建替换字符串 ---

		; 在 AHK 的 RegExReplace 替换字符串中:
		; * `$1` 表示第一个捕获组 (即匹配的 match 文本)
		; * `$$` 表示字面量 `$` 符号

		; 处理 `$`: AHK 的 RegExReplace 替换参数中，$$ 转换为 $。
		SafeInsert := StrReplace(insert, "$", "$$")

		if (position == "Before") {
			; 插入内容 + 捕获组1 => ${safeInsert}$1
			Replacement := SafeInsert . "$1"
		} else { ; position == "after"
			; 捕获组1 + 插入内容 => $1${safeInsert}
			Replacement := "$1" . SafeInsert
		}

		; --- 4. 执行替换 ---
		; 替换所有匹配项 (RegExReplace 默认行为)
		return RegExReplace(original, Pattern, Replacement)
	}

	/**
	 * f 替换内容
	 * @param {String} original - 原始字符串
	 * @param {String} match - 待替换的字符串
	 * @param {String} replaceTo - 替换为
	 * @param {'All'| 'First'| 'Last'} range - 替换范围
	 * @param {StringUtils.ExtraOptions} extraOptions - 额外选项，包含 `ignoreCase`(忽略大小写) 和 `isExactMatch`(全字匹配) 的对象
	 * @returns {String} - 返回修改后的字符串
	 */
	static Replace(original, match, replaceTo, range := 'All', extraOptions := {}) {

		; --- 1. 处理选项和默认值 ---
		ignoreCase := extraOptions.HasOwnProp('ignoreCase') ? extraOptions.ignoreCase : false
		isExactMatch := extraOptions.HasOwnProp('isExactMatch') ? extraOptions.isExactMatch : false

		; --- 2. 构建正则表达式 Pattern (与 InsertByMatch 相似) ---

		; 使用 \Q...\E 确保 match 字符串中的所有内容都被视为字面量
		EscapedMatch := "\Q" . match . "\E"

		; 步骤 A: 应用全词匹配 (\b) 和捕获组
		; 注意：这里我们不需要捕获组，因为不需要在 replacement 中引用它
		Pattern := isExactMatch ? "\b" . EscapedMatch . "\b" : EscapedMatch

		; 步骤 B: 应用忽略大小写选项 (i)
		if (ignoreCase) {
			Pattern := "i)" . Pattern  ; i) 选项放在最前面
		}

		; --- 3. 处理替换字符串中的 $ 转义 ---
		; 替换字符串中 $$ 表示字面量 $
		SafeReplaceTo := StrReplace(replaceTo, "$", "$$")

		; --- 4. 根据 Range 确定替换逻辑 ---

		Switch range {

			Case 'First':
				; RegExReplace 的 Limit 参数：1 表示只替换第一个匹配项
				return RegExReplace(original, Pattern, SafeReplaceTo, &Count, 1)

			Case 'Last':
				; AHK 没有内置的 last-replace 功能，需要先找到最后一个匹配项的位置。

				; 使用 RegExMatch 查找所有匹配项
				Matches := [] ; 存储所有匹配结果
				StartPos := 1

				; 循环查找所有匹配项。注意，RegExMatch 的 Options 必须与 Pattern 保持一致
				while (RegExMatch(original, Pattern, &Match, StartPos)) {
					Matches.Push({ Text: Match.0, Pos: Match.Pos })
					StartPos := Match.Pos + Match.Len ; 从匹配项后开始下一次搜索
				}

				if (Matches.Length == 0) {
					return original ; 没有匹配项，返回原字符串
				}


				; 获取最后一个匹配项的数据
				LastMatch := Matches[Matches.Length]
				LastIndex := LastMatch.Pos
				MatchedTextLen := StrLen(LastMatch.Text)

				; 将字符串分为三部分，然后拼接
				PartBefore := SubStr(original, 1, LastIndex - 1)
				PartAfter := SubStr(original, LastIndex + MatchedTextLen)

				; 直接拼接：前半部分 + 替换文本 + 后半部分
				return PartBefore . SafeReplaceTo . PartAfter

			Case 'All':
				; RegExReplace 的默认行为是替换所有匹配项
				return RegExReplace(original, Pattern, SafeReplaceTo)
		}
	}

	/**
	 * f 移除内容
	 * @param {String} original - 原始字符串
	 * @param {String} match - 待替换的字符串
	 * @param {'All'| 'First'| 'Last'} range - 替换范围
	 * @param {StringUtils.ExtraOptions} extraOptions - 额外选项，包含 `ignoreCase`(忽略大小写) 和 `isExactMatch`(全字匹配) 的对象
	 * @returns {String} - 返回修改后的字符串
	 */
	static Remove(original, match, range := 'All', extraOptions := {}) {
		return this.Replace(original, match, "", range, extraOptions)
	}


	/**
	 * f 移除字符串中的补零填充
	 * 该函数通过两步正则替换实现：
	 * 1. 移除所有非必需的前导零 (如 007 -> 7)。
	 * 2. 将所有剩余的、由多个零组成的前导零缩减为单个零 (如 000 -> 0)。
	 * @param {String} original - 原始字符串
	 * @returns {String} - 返回修改后的字符串
	 */
	static RemoveZeroPadding(original) {

		; --- 步骤 1: 移除所有非零数字前的冗余零 ---
		; Pattern: 匹配一个或多个零 (0+)，前提是后面跟着一个数字 (>0 的数字序列)
		Pattern1 := "0+([1-9]\d*)"

		; 替换为捕获组 $1 (即非零数字本身)
		original := RegExReplace(original, Pattern1, "$1")

		; 此时: "P000,001" -> "P000,1"

		; --- 步骤 2: 将全零数字 (00...) 缩减为单个零 ---
		; Pattern: 匹配由单词边界 (\b) 包裹的、由两个或更多零 (00+) 组成的序列
		Pattern2 := "\b00+"

		; 替换为单个零 "0"
		original := RegExReplace(original, Pattern2, "0")

		; 此时: "P000,1" -> "P0,1"

		return original
	}

	/**
	 * f [辅助方法] 重复一个字符串 N 次
	 * AHK v2 没有内置 StrRepeat，因此需要手动实现。
	 * @param {String} character - 要重复的字符串
	 * @param {Integer} count - 重复次数
	 * @returns {String} - 重复后的字符串
	 */
	static _StrRepeat(character, count) {
		; 循环是实现重复最通用可靠的方式
		Result := ""
		Loop count {
			Result := Result . character
		}
		return Result
	}

	/**
	 * f 填充字符串
	 * @param {String} original - 原始字符串
	 * @param {String} character - 填充字符
	 * @param {Integer} length - 填充后的总长度
	 * @param {"Left"|"Right"} direction - 填充方向 'Left' | 'Right'
	 * @returns {String} - 返回修改后的字符串
	 */
	static Padding(original, character, length, direction := 'Left') {

		OriginalLen := StrLen(original)

		; 1. 边界检查：如果原始字符串长度已达到或超过目标长度，则返回。
		if (OriginalLen >= length) {
			return original
		}

		; 2. 确定填充长度和填充字符
		PadLength := length - OriginalLen

		; AHK StrRepeat 需要单个字符。如果 character 是多字符，只取第一个。
		FillChar := SubStr(character, 1, 1)

		; 3. 生成填充字符串
		Padding := this._StrRepeat(FillChar, PadLength)

		; 4. 拼接
		if (direction == 'Left') {
			; 左填充 (padStart)
			return Padding . original
		} else if (direction == 'Right') {
			; 右填充 (padEnd)
			return original . Padding
		}

		; 如果 direction 不合法，返回原字符串
		return original
	}


	/**
	 * f 给字符串中的文本进行补零填充 (应用于所有数字序列)
	 * @param {String} original - 原始字符串
	 * @param {Integer} length - 填充后的总长度
	 * @returns {String} - 返回修改后的字符串
	 */
	static ZeroPadding(original, length) {
		static regex := "(\d+)"
		Matches := []
		StartPos := 1

		while (RegExMatch(original, regex, &Match, StartPos)) {
			Matches.InsertAt(1, { Text: Match.0, Pos: Match.Pos })
			StartPos := Match.Pos + Match.Len
		}

		for (Match in Matches) {
			padLen := length - StrLen(Match.Text)
			if (padLen > 0)
				original := StringUtils.InsertByIndex(original, StringUtils._StrRepeat("0", padLen), Match.Pos)
		}

		return original
	}

	/**
	 * 正则替换
	 * @param original 要替换的内
	 * @param regexStr 正则表达式
	 * @param replaceTo 替换表达式
	 * @param {ExtraOptions} extraOptions - 额外选项，包含 `ignoreCase`(忽略大小写) 和 `isExactMatch`(全字匹配) 的对象
	 * @returns {String} 
	 */
	static RegexReplace(original, regexStr, replaceTo, extraOptions := {}) {
		ignoreCase := extraOptions.HasOwnProp("ignoreCase") ? extraOptions.ignoreCase : false
		isExactMatch := extraOptions.HasOwnProp("isExactMatch") ? extraOptions.isExactMatch : false

		; --- 1. 自动转义正则特殊字符 ---
		; 使用 \Q...\E 确保 match 字符串中的所有内容都被视为字面量
		; regexStr := "\Q".regexStr . "\E"

		; --- 2. 应用全字匹配 ---
		if (isExactMatch)
			regexStr := "\b" . regexStr . "\b"

		; --- 3. 忽略大小写 ---
		if (ignoreCase)
			regexStr := "i)" . regexStr

		; --- 4. 替换 ---
		return RegExReplace(original, regexStr, replaceTo)
	}


	/**
	 * f 使路径字符串合法化（去除或替换非法字符）
	 * @param {String} path 原始路径字符串
	 * @param {String} replacement 用于替代非法字符的字符串（默认是 "_"）
	 * @return {String} 合法化后的路径字符串
	 */
	static SanitizePath(path, replacement := "_") {
		; Windows 文件/文件夹名称中不允许的字符：
		; \ / : * ? " < > | 以及控制字符 (0x00–0x1F)
		invalidPattern := "[\\\/:\*\?\" "<>\|\x00-\x1F]"

		; 替换非法字符
		clean := RegExReplace(path, invalidPattern, replacement)

		; 去掉结尾的点和空格（Windows 不允许文件名以它们结尾）
		clean := RegExReplace(clean, "[\. ]+$", "")

		; 如果清理后为空字符串，则返回 "_"
		if (clean = "")
			clean := "_"

		return clean
	}
}