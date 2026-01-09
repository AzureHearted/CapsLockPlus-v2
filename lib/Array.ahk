/*
	名称: Array.ahk
	版本: 0.3 (24.03.23)
	创建日期: 27.08.22
	作者: Descolada

	说明:
	一个实用数组方法的合集。

    Array.Slice(start:=1, end:=0, step:=1)  => 返回数组从 start 到 end 的一段，可选参数 step 用于跳过元素。
    Array.Swap(a, b)                        => 交换数组中索引为 a 和 b 的两个元素。
    Array.Map(func, arrays*)                => 对数组的每个元素执行函数 func，并返回新的数组。
    Array.ForEach(func)                     => 对数组的每个元素调用一次 func，不返回结果。
    Array.Filter(func)                      => 仅保留使 func 返回 true 的元素。
    Array.Reduce(func, initialValue?)       => 累计应用函数 func 到数组的所有元素，可设置初始值。
    Array.IndexOf(value, start:=1)          => 查找数组中第一次出现 value 的位置索引，从 start 开始。
    Array.Find(func, &match?, start:=1)     => 查找第一个使 func 返回 true 的元素并返回索引，同时将该值存入 match。
    Array.Reverse()                         => 反转数组中元素的顺序。
    Array.Count(value)                      => 统计数组中 value 出现的次数。
    Array.Sort(OptionsOrCallback?, Key?)    => 对数组进行排序，可传入排序选项或回调函数，也可按对象属性值排序。
    Array.Shuffle()                         => 随机打乱数组中元素的顺序。
    Array.Join(delim:=",")                  => 使用指定分隔符将数组所有元素连接为一个字符串。
    Array.Flat()                            => 将嵌套数组展平成单层数组。
    Array.Extend(arr)                       => 将另一个数组 arr 的所有内容追加到当前数组的末尾。
*/


Array.Prototype.base := Array2

class Array2 {
	/**
	 * 返回数组中从 “start” 到 “end” 的一部分，可选地通过 “step” 跳过元素。
	 * 会修改原始数组。
	 * @param start 可选：起始索引。默认值为 1。
	 * @param end 可选：结束索引。可为负数。默认值为 0（包含最后一个元素）。
	 * @param step 可选：指定增量的整数。默认值为 1。
	 * @returns {Array}
	 */

	static Slice(start := 1, end := 0, step := 1) {
		len := this.Length, i := start < 1 ? len + start : start, j := Min(end < 1 ? len + end : end, len), r := [], reverse := False
		if len = 0
			return []
		if i < 1
			i := 1
		if step = 0
			Throw Error("Slice: step cannot be 0", -1)
		else if step < 0 {
			while i >= j {
				r.Push(this[i])
				i += step
			}
		} else {
			while i <= j {
				r.Push(this[i])
				i += step
			}
		}
		return this := r
	}
	/**
	 * 交换索引为 a 和 b 的元素
	 * @param a 要交换的第一个元素的索引
	 * @param b 要交换的第二个元素的索引
	 * @returns {Array}
	 */
	static Swap(a, b) {
		temp := this[b]
		this[b] := this[a]
		this[a] := temp
		return this
	}
	/**
	 * 将一个函数应用到数组中的每个元素（会修改原数组）。
	 * @param func 接受一个参数的映射函数。
	 * @param arrays 可选：在映射函数中同时传入的其他数组。
	 * @returns {Array}
	 */
	static Map(func, arrays*) {
		if !HasMethod(func)
			throw ValueError("Map: func must be a function", -1)
		for i, v in this {
			bf := func.Bind(v?)
			for _, vv in arrays
				bf := bf.Bind(vv.Has(i) ? vv[i] : unset)
			try bf := bf()
			this[i] := bf
		}
		return this
	}
	/**
	 * 对数组中的每个元素执行指定函数。
	 * @param func 回调函数，参数格式为 Callback(value[, index, array])。
	 * @returns {Array}
	 */
	static ForEach(func) {
		if !HasMethod(func)
			throw ValueError("ForEach: func must be a function", -1)
		for i, v in this
			func(v, i, this)
		return this
	}
	/**
	 * 保留满足指定函数条件的元素。
	 * @param func 过滤函数，接收一个参数。
	 * @returns {Array}
	 */
	static Filter(func) {
		if !HasMethod(func)
			throw ValueError("Filter: func must be a function", -1)
		r := []
		for v in this
			if func(v)
				r.Push(v)
		return this := r
	}
	/**
	 * 将一个函数累积地应用于数组中的所有元素，可选初始值。
	 * @param func 接收两个参数并返回一个值的函数。
	 * @param initialValue 可选：初始值。如果省略，则使用数组的第一个元素作为初始值。
	 * @returns {func 返回类型}
	 * @example
	 * [1,2,3,4,5].Reduce((a,b) => (a+b)) ; 返回 15（所有数字的和）
	 */
	static Reduce(func, initialValue?) {
		if !HasMethod(func)
			throw ValueError("Reduce: func must be a function", -1)
		len := this.Length + 1
		if len = 1
			return initialValue ?? ""
		if IsSet(initialValue)
			out := initialValue, i := 0
		else
			out := this[1], i := 1
		while ++i < len {
			out := func(out, this[i])
		}
		return out
	}
	/**
	 * 在数组中查找某个值并返回其索引。
	 * @param value 要查找的值。
	 * @param start 可选：开始查找的索引。默认值为 1。
	 */
	static IndexOf(value, start := 1) {
		if !IsInteger(start)
			throw ValueError("IndexOf: start value must be an integer")
		for i, v in this {
			if i < start
				continue
			if v == value
				return i
		}
		return 0
	}
	/**
	 * 查找满足指定函数条件的值并返回其索引。
	 * @param func 条件函数，接受一个参数。
	 * @param match 可选：用于接收找到的值。
	 * @param start 可选：开始查找的索引。默认值为 1。
	 * @example
	 * [1,2,3,4,5].Find((v) => (Mod(v,2) == 0)) ; 返回 2
	 */
	static Find(func, &match?, start := 1) {
		if !HasMethod(func)
			throw ValueError("Find: func must be a function", -1)
		for i, v in this {
			if i < start
				continue
			if func(v) {
				match := v
				return i
			}
		}
		return 0
	}
	/**
	 * 反转数组。
	 * @example
	 * [1,2,3].Reverse() ; 返回 [3,2,1]
	 */
	static Reverse() {
		len := this.Length + 1, max := (len // 2), i := 0
		while ++i <= max
			this.Swap(i, len - i)
		return this
	}
	/**
	 * 统计某个值在数组中出现的次数。
	 * @param value 要统计的值，也可以是一个函数。
	 */
	static Count(value) {
		count := 0
		if HasMethod(value) {
			for v in this
				if value(v?)
					count++
		} else
			for v in this
				if v == value
					count++
		return count
	}
	/**
	 * 对数组进行排序，可选按对象键排序。
	 * @param OptionsOrCallback 可选：可以是一个回调函数，或者以下选项之一：
	 * 
	 *     N => 数组被视为仅包含数值（默认选项）
	 *     C, C1 或 COn => 区分大小写地对字符串排序
	 *     C0 或 COff => 不区分大小写地对字符串排序
	 * 
	 *     回调函数应接受两个参数 elem1 和 elem2，并返回一个整数：
	 *     返回 < 0 表示 elem1 小于 elem2
	 *     返回 0 表示 elem1 等于 elem2
	 *     返回 > 0 表示 elem1 大于 elem2
	 * @param Key 可选：如果要对基础类型数组（字符串、数字等）排序，可省略。
	 *     若为对象数组，则在此指定用于排序的对象键名。
	 * @returns {Array}
	 */
	static Sort(optionsOrCallback := "N", key?) {
		static sizeofFieldType := 16 ; Same on both 32-bit and 64-bit
		if HasMethod(optionsOrCallback)
			pCallback := CallbackCreate(CustomCompare.Bind(optionsOrCallback), "F Cdecl", 2), optionsOrCallback := ""
		else {
			if InStr(optionsOrCallback, "N")
				pCallback := CallbackCreate(IsSet(key) ? NumericCompareKey.Bind(key) : NumericCompare, "F CDecl", 2)
			if RegExMatch(optionsOrCallback, "i)C(?!0)|C1|COn")
				pCallback := CallbackCreate(IsSet(key) ? StringCompareKey.Bind(key, , True) : StringCompare.Bind(, , True), "F CDecl", 2)
			if RegExMatch(optionsOrCallback, "i)C0|COff")
				pCallback := CallbackCreate(IsSet(key) ? StringCompareKey.Bind(key) : StringCompare, "F CDecl", 2)
			if InStr(optionsOrCallback, "Random")
				pCallback := CallbackCreate(RandomCompare, "F CDecl", 2)
			if !IsSet(pCallback)
				throw ValueError("No valid options provided!", -1)
		}
		mFields := NumGet(ObjPtr(this) + (8 + 3 * A_PtrSize), "Ptr") ; 0 is VTable. 2 is mBase, 4 is FlatVector, 5 is mLength and 6 is mCapacity
		DllCall("msvcrt.dll\qsort", "Ptr", mFields, "UInt", this.Length, "UInt", sizeofFieldType, "Ptr", pCallback, "Cdecl")
		CallbackFree(pCallback)
		if RegExMatch(optionsOrCallback, "i)R(?!a)")
			this.Reverse()
		if InStr(optionsOrCallback, "U")
			this := this.Unique()
		return this

		CustomCompare(compareFunc, pFieldType1, pFieldType2) => (ValueFromFieldType(pFieldType1, &fieldValue1), ValueFromFieldType(pFieldType2, &fieldValue2), compareFunc(fieldValue1, fieldValue2))
		NumericCompare(pFieldType1, pFieldType2) => (ValueFromFieldType(pFieldType1, &fieldValue1), ValueFromFieldType(pFieldType2, &fieldValue2), fieldValue1 - fieldValue2)
		NumericCompareKey(key, pFieldType1, pFieldType2) => (ValueFromFieldType(pFieldType1, &fieldValue1), ValueFromFieldType(pFieldType2, &fieldValue2), fieldValue1.%key% -fieldValue2.%key%)
		StringCompare(pFieldType1, pFieldType2, casesense := False) => (ValueFromFieldType(pFieldType1, &fieldValue1), ValueFromFieldType(pFieldType2, &fieldValue2), StrCompare(fieldValue1 "", fieldValue2 "", casesense))
		StringCompareKey(key, pFieldType1, pFieldType2, casesense := False) => (ValueFromFieldType(pFieldType1, &fieldValue1), ValueFromFieldType(pFieldType2, &fieldValue2), StrCompare(fieldValue1.%key% "", fieldValue2.%key% "", casesense))
		RandomCompare(pFieldType1, pFieldType2) => (Random(0, 1) ? 1 : -1)

		ValueFromFieldType(pFieldType, &fieldValue?) {
			static SYM_STRING := 0, PURE_INTEGER := 1, PURE_FLOAT := 2, SYM_MISSING := 3, SYM_OBJECT := 5
			switch SymbolType := NumGet(pFieldType + 8, "Int") {
				case PURE_INTEGER: fieldValue := NumGet(pFieldType, "Int64")
				case PURE_FLOAT: fieldValue := NumGet(pFieldType, "Double")
				case SYM_STRING: fieldValue := StrGet(NumGet(pFieldType, "Ptr") + 2 * A_PtrSize)
				case SYM_OBJECT: fieldValue := ObjFromPtrAddRef(NumGet(pFieldType, "Ptr"))
				case SYM_MISSING: return
			}
		}
	}
	/**
	 * 随机打乱数组。比使用 Array.Sort(,"Random N") 略快。
	 * @returns {Array}
	 */
	static Shuffle() {
		len := this.Length
		Loop len - 1
			this.Swap(A_index, Random(A_index, len))
		return this
	}
	/**
	 * 返回一个去重后的新数组，移除所有重复元素。
	 * @returns {Array} 去重后的数组。
	 * @example
	 * [1,2,2,3,3,3].Unique() ; 返回 [1,2,3]
	 */
	static Unique() {
		unique := Map()
		for v in this
			unique[v] := 1
		return [unique*]
	}
	/**
	 * 使用指定的分隔符将所有元素连接成一个字符串。
	 * @param delim 可选：要使用的分隔符。默认是逗号。
	 * @returns {String}
	 */
	static Join(delim := ",") {
		result := ""
		for v in this
			result .= v delim
		return (len := StrLen(delim)) ? SubStr(result, 1, -len) : result
	}
	/**
	 * 将嵌套数组展开为一维数组。
	 * @returns {Array}
	 * @example
	 * [1,[2,[3]]].Flat() ; 返回 [1,2,3]
	 */
	static Flat() {
		r := []
		for v in this {
			if Type(v) = "Array"
				r.Extend(v.Flat())
			else
				r.Push(v)
		}
		return this := r
	}
	/**
	 * 将另一个数组的内容追加到当前数组的末尾。
	 * @param arr 用于扩展当前数组的数组。
	 * @returns {Array}
	 */
	static Extend(arr) {
		if !HasMethod(arr, "__Enum")
			throw ValueError("Extend: arr must be an iterable")
		for v in arr
			this.Push(v)
		return this
	}
}