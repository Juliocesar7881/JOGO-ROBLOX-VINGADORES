-- Quotes are local to this player. One slow Marketplace request must not
-- hold every shop button behind the full catalog or leave it loading forever.
local ProductQuotes = {}
ProductQuotes.__index = ProductQuotes

function ProductQuotes.new(ctx)
	return setmetatable({ ctx = ctx, queue = {}, pending = {}, active = 0 }, ProductQuotes)
end

function ProductQuotes:_pump()
	local ctx = self.ctx
	local delay, spawn = ctx.delay or task.delay, ctx.spawn or task.spawn
	while self.active < 3 and #self.queue > 0 do
		local item = table.remove(self.queue, 1)
		if ctx.cache[item.cacheKey] ~= nil or self.pending[item.cacheKey] then continue end
		local token = {}
		self.pending[item.cacheKey] = token
		self.active += 1
		local function finish(value)
			if self.pending[item.cacheKey] ~= token then return end
			self.pending[item.cacheKey] = nil
			ctx.cache[item.cacheKey] = value
			self.active -= 1
			ctx.updated()
			self:_pump()
		end
		delay(12, function() finish("retry") end)
		spawn(function()
			local ok, value = pcall(ctx.quote, item.kind, item.key)
			if not ok or value == nil then value = "retry" end
			finish(value)
		end)
	end
end

function ProductQuotes:Fetch(kind)
	local ctx = self.ctx
	local groups = { hero = ctx.catalog.Heroes, pass = ctx.catalog.Passes, product = ctx.catalog.Consumables }
	local p = ctx.profile()
	-- Switching tabs prioritizes the new tab; old in-flight quotes may finish,
	-- but unseen catalog entries no longer delay the visible products.
	self.queue = {}
	local function add(itemKind, key, def)
		local cacheKey = itemKind .. ":" .. key
		local owned = itemKind == "hero" and (p.heroes or {})[key] or itemKind == "pass" and (p.passes or {})[key]
		if not owned and ctx.cache[cacheKey] == nil and not self.pending[cacheKey] then
			table.insert(self.queue, { kind = itemKind, key = key, cacheKey = cacheKey, price = def.price or 0 })
		end
	end
	for key, def in pairs(groups[kind] or {}) do add(kind, key, def) end
	table.sort(self.queue, function(a, b) return a.price < b.price or a.price == b.price and a.key < b.key end)
	local starter = ctx.catalog.Consumables.starterPack
	if starter and not p.starterPack and kind ~= "product" then add("product", "starterPack", starter) end
	self:_pump()
end

return ProductQuotes
