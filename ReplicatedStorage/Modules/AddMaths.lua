local AddMaths = {}

local suffixes = {
	{1e33, "d"},
	{1e30, "n"},
	{1e27, "oc"},
	{1e24, "sT"},
	{1e21, "s"},
	{1e18, "qT"},
	{1e15, "q"},
	{1e12, "t"},
	{1e9, "b"},
	{1e6, "m"},
	{1e3, "k"},
	{1e0, ""},
}

-- Custom round function to 2 decimal places
local function roundToTwoDecimals(num)
	return math.round(num * 100) / 100
end

function AddMaths:intToRoman(n: number): string?
	if n ~= math.floor(n) or n < 1 or n > 3999 then
		return nil
	end

	local values = {1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1}
	local symbols = {"M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"}

	local result = {}
	for i = 1, #values do
		while n >= values[i] do
			n -= values[i]
			table.insert(result, symbols[i])
		end
	end

	return table.concat(result)
end

function AddMaths:formatNumber(n)
	for i, v in ipairs(suffixes) do
		local value, suffix = v[1], v[2]
		if n >= value then
			local short = roundToTwoDecimals(n / value)

			-- If rounding caused overflow (e.g. 999.999 -> 1000), use the next higher suffix
			if short >= 1000 and i > 1 then
				local nextValue, nextSuffix = suffixes[i - 1][1], suffixes[i - 1][2]
				local nextShort = roundToTwoDecimals(n / nextValue)
				return tostring(nextShort) .. nextSuffix
			end

			return tostring(short) .. suffix
		end
	end
	return tostring(n)
end


local function is_repeating_decimal(n)
	if math.abs(n) < 0.001 then
		return false -- Don't round very small precise numbers
	end

	local str = string.format("%.10f", n)
	local dot = string.find(str, "%.")
	if not dot then return false end

	local decimals = string.sub(str, dot + 1)
	local trimmed = decimals:gsub("0+$", "")

	-- If more than 2 meaningful decimal digits, consider it unstable
	return #trimmed > 2
end

function AddMaths:round_if_repeating(n)
	if is_repeating_decimal(n) then
		return math.floor(n * 100 + 0.5) / 100 -- round to 2 decimal places
	else
		return n
	end
end

function AddMaths:fix_dec_bug(n, maxDecimals)
	maxDecimals = maxDecimals or 2

	local factor = 10 ^ maxDecimals
	local rounded = math.round(n * factor) / factor

	local s = string.format("%." .. maxDecimals .. "f", rounded)
	s = s:gsub("%.?0+$", "") -- remove trailing zeros and dot

	return s
end

return AddMaths
