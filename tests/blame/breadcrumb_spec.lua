-- tests/lua/breadcrumb_spec.lua
local Breadcrumb = require("blame.breadcrumb")
local assert = require("luassert")

describe("blame.breadcrumb", function()
	it("initializes a new breadcrumb", function()
		local bc = Breadcrumb:new()
		assert.are.same({}, bc.stack)
		assert.is_nil(bc:current())
	end)

	it("pushes a new item", function()
		local bc = Breadcrumb:new()
		local item = { commit_info = { header = { commit = "hash1" } }, cursor_pos = { 1, 0 } }
		local added = bc:push(item)
		assert.is_true(added)
		assert.are.same({ item }, bc.stack)
		assert.are.equal(item, bc:current())
	end)

	it("does not push a duplicate item", function()
		local bc = Breadcrumb:new()
		local item = { commit_info = { header = { commit = "hash1" } }, cursor_pos = { 1, 0 } }
		bc:push(item)
		local added = bc:push(item)
		assert.is_false(added)
		assert.are.same({ item }, bc.stack)
		assert.are.equal(item, bc:current())
	end)

	it("pushes multiple items", function()
		local bc = Breadcrumb:new()
		local item1 = { commit_info = { header = { commit = "hash1" } }, cursor_pos = { 1, 0 } }
		local item2 = { commit_info = { header = { commit = "hash2" } }, cursor_pos = { 2, 0 } }
		bc:push(item1)
		bc:push(item2)
		assert.are.same({ item1, item2 }, bc.stack)
		assert.are.equal(item2, bc:current())
	end)

	it("pops an item", function()
		local bc = Breadcrumb:new()
		local item1 = { commit_info = { header = { commit = "hash1" } }, cursor_pos = { 1, 0 } }
		local item2 = { commit_info = { header = { commit = "hash2" } }, cursor_pos = { 2, 0 } }
		bc:push(item1)
		bc:push(item2)
		local popped_item = bc:pop()
		assert.are.equal(item2, popped_item)
		assert.are.equal(item1, bc:current())
		assert.are.same({ item1 }, bc.stack)
	end)

	it("returns nil when popping from an empty stack", function()
		local bc = Breadcrumb:new()
		local item = bc:pop()
		assert.is_nil(item)
		assert.is_nil(bc:current())
		assert.are.same({}, bc.stack)
	end)

	it("does not push '00000000' to the stack", function()
		local bc = Breadcrumb:new()
		local item = {
			commit_info = { header = { commit = "0000000000000000000000000000000000000000" } },
			cursor_pos = { 1, 0 },
		}
		local added = bc:push(item)
		assert.is_false(added)
		assert.are.same({}, bc.stack)
		assert.is_nil(bc:current())
	end)
end)
