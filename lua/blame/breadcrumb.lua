-- lua/blame/breadcrumb.lua

---@class BreadcrumbItem
---@field commit_info Porcelain|nil
---@field cursor_pos number[]|nil

---@class Breadcrumb
---@field stack BreadcrumbItem[]
local Breadcrumb = {}
Breadcrumb.__index = Breadcrumb

---@return Breadcrumb
function Breadcrumb:new()
	local instance = {
		stack = {}, -- Stack will store all visited items, including the current one
	}
	setmetatable(instance, Breadcrumb)
	return instance
end

---@return BreadcrumbItem|nil
function Breadcrumb:current()
	return self.stack[#self.stack] -- The last item on the stack is the current one
end

---@param new_item BreadcrumbItem
---@return boolean
function Breadcrumb:push(new_item)
	-- Do not add the special revision "00000000" to the stack
	if new_item.commit_info and new_item.commit_info.header.commit:match("^00000000") then
		return false -- not added
	end
	-- Check if the new_item is the same as the current item
	local current = self:current()
	if
		current
		and new_item.commit_info
		and current.commit_info
		and new_item.commit_info.header.commit == current.commit_info.header.commit
	then
		return false -- not added
	end
	table.insert(self.stack, new_item) -- Add the new item to the stack
	return true -- added
end

---@return BreadcrumbItem|nil
function Breadcrumb:pop()
	return table.remove(self.stack) -- The item that *was* current
end

return Breadcrumb
