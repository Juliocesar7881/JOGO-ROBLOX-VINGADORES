-- Promo codes, server-only: nothing in this module ever replicates, so a
-- code nobody announced yet cannot be read out of ReplicatedStorage.
--
-- Key: the code in capitals (letters and digits only; players may type it in
-- any case, with spaces and with or without accents: "lançamento" is LANCAMENTO). Value: what it pays, in the same shape as every
-- other reward ({ gold?, xp?, chest?, title? }), plus an optional `expires`
-- (unix seconds, UTC) after which the code stops working. Each account can
-- redeem each code once. Add a code here, rebuild, publish; or, without a
-- publish, in Creator Hub > Configs under the JSON key "codes" (init.server
-- reads it, Rules.ConfigCodes checks every entry; see docs/DEPLOYMENT.md).
return {
	MULTIVERSO = { gold = 500 },
	DOOMSDAY = { gold = 300, xp = 100 },
	ULTIMATE = { gold = 1000, chest = "rare", expires = 1798761600 }, -- 2027-01-01 00:00 UTC
	-- The launch code (typed with or without the cedilla and tilde: LANÇAMENTO works too).
	LANCAMENTO = { gold = 300, chest = "rare" },
}
