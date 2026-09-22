-- Promo codes, server-only: nothing in this module ever replicates, so a
-- code nobody announced yet cannot be read out of ReplicatedStorage.
--
-- Key: the code in capitals (letters and digits only; players may type it in
-- any case, with spaces). Value: what it pays, in the same shape as every
-- other reward ({ gold?, xp?, chest?, title? }), plus an optional `expires`
-- (unix seconds, UTC) after which the code stops working. Each account can
-- redeem each code once. Add a code here, rebuild, publish.
return {
	VINGADORES = { gold = 500 },
	DOOMSDAY = { gold = 300, xp = 100 },
	ULTIMATE = { gold = 1000, chest = "rare", expires = 1798761600 }, -- 2027-01-01 00:00 UTC
}
