-- lua/blame/breadcrumb.lua

local Breadcrumb = {}
Breadcrumb.__index = Breadcrumb

function Breadcrumb:new()
	local instance = {
		stack = {}, -- Stack will store all visited items, including the current one
	}
	setmetatable(instance, Breadcrumb)
	return instance
end

function Breadcrumb:current()
	return self.stack[#self.stack] -- The last item on the stack is the current one
end

function Breadcrumb:push(new_item)
	-- Do not add the special revision "00000000" to the stack
	if new_item == "00000000" then
		return false -- not added
	end
	-- Check if the new_item is the same as the current item
	if new_item == self:current() then
		return false -- not added
	end
	table.insert(self.stack, new_item) -- Add the new item to the stack
	return true -- added
end

function Breadcrumb:pop()
	return table.remove(self.stack) -- The item that *was* current
end

return Breadcrumb
