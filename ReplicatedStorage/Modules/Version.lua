local version = {
	beta = true,
	build = 1,
	ver = "1.0",
}

function version.display()
	if version.beta == true then
		return ("v" .. version.ver .. " (Beta " .. version.build .. ")")
	end
	
	return ("v" .. version.ver)
end

return version
