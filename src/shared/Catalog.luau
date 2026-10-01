--!nonstrict
-- Data only: runnable both inside Roblox and in the standalone Luau test runner.
--
-- Every number a designer would want to tune lives here. The rules that turn
-- these numbers into behaviour are in Rules.luau, so a new hero, ability, card
-- or chest is a data change, never a new code path.
local function text(pt, en)
	return { pt = pt, en = en }
end

-- Branch effects are data. After the fifth upgrade a tower applies its branch's
-- list, in order, on top of the hero's base numbers:
--   set = replace the stat, mul = multiply it, add = add to it.
local function set(key, value) return { op = "set", key = key, value = value } end
local function mul(key, value) return { op = "mul", key = key, value = value } end
local function add(key, value) return { op = "add", key = key, value = value } end

local Catalog = {}

-- string.upper only knows ASCII, so "Baú Lendário" became "BAú LENDáRIO" on
-- every sign and button that shouts a name. Every uppercase display of
-- Portuguese text goes through this instead.
local ACCENT_UPPER = {
	["á"] = "Á", ["à"] = "À", ["â"] = "Â", ["ã"] = "Ã", ["é"] = "É", ["ê"] = "Ê",
	["í"] = "Í", ["ó"] = "Ó", ["ô"] = "Ô", ["õ"] = "Õ", ["ú"] = "Ú", ["ü"] = "Ü", ["ç"] = "Ç",
}
function Catalog.Upper(value)
	local result = string.upper(tostring(value or ""))
	for lower, upper in pairs(ACCENT_UPPER) do result = string.gsub(result, lower, upper) end
	return result
end

--==============================================================================
-- Rarity
--==============================================================================
-- robux: what the direct-purchase shop asks for a hero of this rarity. The rarer
-- the hero, the more it costs, exactly like its odds in a chest.
-- abilityCost: multiplies the gold price of every ability upgrade.
-- duplicate: what a chest turns a hero you already own into.
-- placeLimit: how many towers of one hero of this rarity a commander may field.
Catalog.RarityOrder = { "common", "rare", "epic", "legendary", "mythic" }
Catalog.Rarities = {
	common = { id = "common", name = text("Comum", "Common"), color = { 190, 200, 212 }, robux = 79, placeLimit = 8, abilityCost = 1, duplicate = { gold = 150, mastery = 60 } },
	rare = { id = "rare", name = text("Raro", "Rare"), color = { 84, 170, 255 }, robux = 199, placeLimit = 6, abilityCost = 1.4, duplicate = { gold = 300, mastery = 120 } },
	epic = { id = "epic", name = text("Épico", "Epic"), color = { 176, 108, 255 }, robux = 449, placeLimit = 5, abilityCost = 2, duplicate = { gold = 600, mastery = 250 } },
	legendary = { id = "legendary", name = text("Lendário", "Legendary"), color = { 255, 188, 62 }, robux = 999, placeLimit = 4, abilityCost = 3, duplicate = { gold = 1200, mastery = 500 } },
	mythic = { id = "mythic", name = text("Mítico", "Mythic"), color = { 255, 84, 112 }, robux = 1999, placeLimit = 3, abilityCost = 4.5, duplicate = { gold = 2500, mastery = 1000 } },
}

--==============================================================================
-- Chests
--==============================================================================
-- Heroes are found in chests, paid for with Gold. The rare chest costs half of
-- the legendary one, and it is the legendary chest that holds the best heroes,
-- with the best of them deliberately the least likely. Odds are percentages,
-- sum to 100 and are shown to the player as they are.
-- pity: after this many legendary-chest openings without a hero of at least
-- that rarity, the next one is guaranteed to be one.
Catalog.ChestOrder = { "rare", "legendary" }
Catalog.Chests = {
	rare = {
		id = "rare", name = text("Baú Raro", "Rare Chest"), cost = 1000, color = { 84, 170, 255 },
		description = text("Heróis comuns, raros e, com sorte, épicos.", "Common, rare and, with luck, epic heroes."),
		odds = { common = 34, rare = 44, epic = 20, legendary = 2, mythic = 0 },
	},
	legendary = {
		id = "legendary", name = text("Baú Lendário", "Legendary Chest"), cost = 2000, color = { 255, 188, 62 },
		description = text("Os melhores heróis do jogo. Os mais poderosos são raros.", "The best heroes in the game. The strongest are rare."),
		odds = { common = 0, rare = 30, epic = 42, legendary = 22, mythic = 6 },
		pity = { after = 10, minimum = "legendary" },
	},
}

--==============================================================================
-- Heroes
--==============================================================================
-- Order is the display order everywhere: by rarity, then by story.
Catalog.HeroOrder = {
	"ironman", "hawkeye", "falcon", "bucky",
	"spiderman", "widow", "antman", "wasp", "rocket", "daredevil", "shangchi",
	"captain", "panther", "hulk", "vision", "warmachine", "starlord", "groot",
	"thor", "wanda", "strange", "ghostrider",
	"captainmarvel", "silversurfer",
}
-- pickup: this hero's towers pull in their owner's match Gold that lands
-- within that many studs (scavengers: Falcão, Homem-Formiga, Rocket, Senhor das
-- Estrelas). It only saves walking; it never creates Gold.
-- Every hero owns exactly one active ability. In a match, the active ability
-- is the one belonging to the hero standing in the FIRST slot of the loadout.
Catalog.Heroes = {
	--- Common ---------------------------------------------------------------
	ironman = {
		id = "ironman", rarity = "common", starter = true, ability = "repulsorBarrage",
		name = text("Volt", "Volt"), role = text("Dano tecnológico versátil", "Versatile tech damage"), cost = 250,
		description = text("Rajadas tecnológicas atingem alvos terrestres e aéreos.", "Technology blasts strike ground and flying targets."),
		damage = 20, range = 27, interval = 0.9, color = { 52, 140, 245 }, attack = "single", damageType = "tech", air = true,
		branches = {
			{ name = text("Mísseis Faísca", "Spark Missiles"), description = text("Explosões atingem grupos inteiros.", "Explosions strike entire groups."), mods = { set("attack", "splash"), set("splash", 8) } },
			{ name = text("Feixe Central", "Core Beam"), description = text("Laser perfura a armadura dos inimigos.", "A laser penetrates enemy armor."), mods = { set("armorPierce", 0.65), mul("damage", 1.35) } },
		},
	},
	hawkeye = {
		id = "hawkeye", rarity = "common", starter = true, ability = "deadeye",
		name = text("Lince", "Lynx"), role = text("Longo alcance e alvos prioritários", "Long range, priority targets"), cost = 180,
		description = text("Arqueiro de longo alcance, excelente contra alvos prioritários.", "A long-range archer, excellent against priority targets."),
		damage = 27, range = 33, interval = 1.6, color = { 70, 160, 96 }, attack = "single", damageType = "physical", air = true,
		branches = {
			{ name = text("Flechas explosivas", "Explosive Arrows"), description = text("Flechas causam dano em área.", "Arrows deal area damage."), mods = { set("attack", "splash"), set("splash", 7) } },
			{ name = text("Precisão absoluta", "Perfect Aim"), description = text("Dano extra contra chefes e elites.", "Extra damage against bosses and elites."), mods = { set("bossDamage", 0.8), add("range", 8) } },
		},
	},
	falcon = {
		id = "falcon", rarity = "common", ability = "airCommand",
		name = text("Cotovia", "Skylark"), role = text("Ataque rápido contra voadores", "Fast strikes against flyers"), cost = 220,
		description = text("Rasantes rápidos: ótimo contra voadores e alvos ágeis.", "Fast dives: great against flyers and agile targets."),
		pickup = 14, damage = 16, range = 30, interval = 0.68, color = { 72, 160, 240 }, attack = "single", damageType = "physical", air = true,
		branches = {
			{ name = text("Rasante", "Dive Bomb"), description = text("Mais dano e mais alcance.", "More damage and more range."), mods = { mul("damage", 1.3), add("range", 6) } },
			{ name = text("Drone Pluma", "Plume Drone"), description = text("Ataca quase o dobro de vezes.", "Attacks almost twice as often."), mods = { mul("interval", 0.6) } },
		},
	},
	bucky = {
		id = "bucky", rarity = "common", ability = "ambush",
		name = text("Sargento Prata", "Silver Sergeant"), role = text("Perfuração de armadura", "Armor piercing"), cost = 300,
		description = text("Tiros secos que atravessam a armadura inimiga.", "Dry shots that pierce enemy armor."),
		damage = 28, range = 28, interval = 1.0, color = { 120, 140, 84 }, attack = "single", damageType = "physical", air = false, armorPierce = 0.15,
		branches = {
			{ name = text("Braço de titânio", "Titanium Arm"), description = text("Perfura quase toda a armadura.", "Pierces almost all armor."), mods = { set("armorPierce", 0.5), mul("damage", 1.2) } },
			{ name = text("Atirador de elite", "Sharpshooter"), description = text("Alcance enorme e dano contra chefes.", "Huge range and boss damage."), mods = { add("range", 10), set("bossDamage", 0.5) } },
		},
	},
	--- Rare -----------------------------------------------------------------
	spiderman = {
		id = "spiderman", rarity = "rare", ability = "webField",
		name = text("Laçadora", "Lasso"), role = text("Desaceleração e controle", "Slowing and crowd control"), cost = 280,
		description = text("Laços mantêm os infectados dentro do alcance da equipe.", "Lassos keep the infected within your team's range."),
		damage = 14, range = 24, interval = 1.1, color = { 150, 84, 226 }, attack = "splash", damageType = "physical", air = false, splash = 7, slow = 0.22,
		branches = {
			{ name = text("Rede urbana", "Urban Net"), description = text("Redes cobrem uma área muito maior.", "Nets cover a much larger area."), mods = { set("splash", 11), set("slow", 0.38) } },
			{ name = text("Laço de impacto", "Impact Lasso"), description = text("Mais dano e controle concentrado.", "More damage and concentrated control."), mods = { mul("damage", 2.1), set("slow", 0.48) } },
		},
	},
	widow = {
		id = "widow", rarity = "rare", ability = "widowBite",
		name = text("Sombra", "Shade"), role = text("Revela camuflados e marca alvos", "Reveals hidden enemies, marks targets"), cost = 260,
		description = text("Revela camuflados e marca inimigos para a equipe.", "Reveals hidden enemies and marks targets for the team."),
		damage = 14, range = 25, interval = 0.75, color = { 120, 100, 220 }, attack = "single", damageType = "tech", air = true, reveal = true, support = true, mark = 0.08,
		branches = {
			{ name = text("Reconhecimento", "Reconnaissance"), description = text("Revela inimigos em um alcance maior.", "Reveals enemies in a wider range."), mods = { add("range", 14), set("mark", 0.12) } },
			{ name = text("Alvo marcado", "Marked Target"), description = text("Alvos marcados recebem mais dano de toda a equipe.", "Marked targets take more damage from the entire team."), mods = { set("mark", 0.25), mul("damage", 1.2) } },
		},
	},
	antman = {
		id = "antman", rarity = "rare", ability = "growth",
		name = text("Titã de Bolso", "Pocket Titan"), role = text("Ataques rápidos e pisões", "Fast attacks and stomps"), cost = 380,
		description = text("Ataques rápidos alternam com pisões gigantes.", "Quick attacks alternate with giant stomps."),
		pickup = 14, damage = 22, range = 26, interval = 0.7, color = { 120, 210, 80 }, attack = "single", damageType = "tech", air = false, splash = 8, stompEvery = 5,
		branches = {
			{ name = text("Gigante", "Giant"), description = text("Pisões gigantes acontecem com mais frequência.", "Giant stomps happen more frequently."), mods = { set("periodicSplash", 2) } },
			{ name = text("Impacto Quântico", "Quantum Impact"), description = text("Pisões alcançam uma área enorme.", "Stomps reach an enormous area."), mods = { set("splash", 16), set("periodicSplash", 4) } },
		},
	},
	wasp = {
		id = "wasp", rarity = "rare", ability = "swarmSting",
		name = text("Pirilampo", "Firefly"), role = text("Ferrão rápido que desacelera", "Fast slowing stings"), cost = 240,
		description = text("Ferroadas elétricas rápidas que atrasam o alvo.", "Fast electric stings that slow the target."),
		damage = 10, range = 22, interval = 0.4, color = { 160, 235, 100 }, attack = "single", damageType = "tech", air = true, slow = 0.15,
		branches = {
			{ name = text("Enxame", "Swarm"), description = text("Cada ferroada salta entre vários inimigos.", "Each sting jumps between several enemies."), mods = { set("attack", "chain"), set("chain", 4) } },
			{ name = text("Ferrão bioelétrico", "Bio-electric Sting"), description = text("Muito mais dano e muito mais lentidão.", "Far more damage and far more slow."), mods = { mul("damage", 1.6), set("slow", 0.35) } },
		},
	},
	rocket = {
		id = "rocket", rarity = "rare", ability = "salvage",
		name = text("Guaxo", "Rascal"), role = text("Explosivos em área", "Area explosives"), cost = 330,
		description = text("Um arsenal improvisado que explode em pequenas áreas.", "An improvised arsenal that bursts in small areas."),
		pickup = 14, damage = 15, range = 26, interval = 1.3, color = { 80, 170, 110 }, attack = "splash", damageType = "tech", air = true, splash = 4.5,
		branches = {
			{ name = text("Arsenal explosivo", "Explosive Arsenal"), description = text("Explosões enormes e mais dano.", "Huge blasts and more damage."), mods = { set("splash", 10), mul("damage", 1.3) } },
			{ name = text("Metralhadora grande", "Big Gun"), description = text("Dispara quase o dobro de vezes.", "Fires almost twice as often."), mods = { mul("interval", 0.6) } },
		},
	},
	daredevil = {
		id = "daredevil", rarity = "rare", ability = "radarSense",
		name = text("Eco", "Echo"), role = text("Enxerga camuflados", "Sees hidden enemies"), cost = 270,
		description = text("Sente inimigos camuflados e ataca em sequência.", "Senses cloaked enemies and strikes in sequence."),
		damage = 17, range = 20, interval = 0.6, color = { 110, 130, 170 }, attack = "single", damageType = "physical", air = false, reveal = true,
		branches = {
			{ name = text("Sentido radar", "Radar Sense"), description = text("Revela e marca inimigos em alcance maior.", "Reveals and marks enemies farther out."), mods = { add("range", 12), set("mark", 0.1) } },
			{ name = text("Bastão duplo", "Twin Batons"), description = text("Mais dano e ritmo acelerado.", "More damage and a faster pace."), mods = { mul("damage", 1.5), mul("interval", 0.8) } },
		},
	},
	shangchi = {
		id = "shangchi", rarity = "rare", ability = "tenRings",
		name = text("Rin", "Rin"), role = text("Combate corpo a corpo veloz", "Fast close combat"), cost = 340,
		description = text("Golpes velozes que rompem a proteção dos inimigos.", "Rapid strikes that break enemy protection."),
		damage = 14, range = 18, interval = 0.4, color = { 50, 170, 125 }, attack = "single", damageType = "physical", air = false, armorPierce = 0.1,
		branches = {
			{ name = text("Anéis Celestes", "Sky Rings"), description = text("Os anéis saltam entre vários inimigos.", "The rings jump between several enemies."), mods = { set("attack", "chain"), set("chain", 4), mul("damage", 1.2) } },
			{ name = text("Punho de jade", "Jade Fist"), description = text("Perfura e enfraquece a armadura.", "Pierces and weakens armor."), mods = { set("armorPierce", 0.6), set("armorShred", 0.15) } },
		},
	},
	--- Epic -----------------------------------------------------------------
	captain = {
		id = "captain", rarity = "epic", ability = "vibraniumShield",
		name = text("Comandante Égide", "Commander Aegis"), role = text("Ricochetes e suporte às torres", "Ricochets and tower support"), cost = 360,
		description = text("O escudo ricocheteia e a liderança fortalece aliados próximos.", "His shield ricochets while leadership strengthens nearby allies."),
		damage = 17, range = 23, interval = 1.05, color = { 24, 170, 160 }, attack = "chain", damageType = "physical", air = false, chain = 4, support = true, supportBoost = 0.06,
		branches = {
			{ name = text("Escudo ofensivo", "Offensive Shield"), description = text("Mais ricochetes e dano por ataque.", "More ricochets and damage per attack."), mods = { set("chain", 6), mul("damage", 1.35) } },
			{ name = text("Todos juntos!", "All Together!"), description = text("Amplia o poder da aura de liderança.", "Strengthens the leadership aura."), mods = { set("supportBoost", 0.18), add("range", 5) } },
		},
	},
	panther = {
		id = "panther", rarity = "epic", ability = "wakandaForever",
		name = text("Ônix", "Onyx"), role = text("Ataques rápidos e enfraquece armadura", "Fast strikes, armor shredding"), cost = 400,
		description = text("Garras de ônix enfraquecem a armadura dos inimigos.", "Onyx claws weaken enemy armor."),
		damage = 19, range = 19, interval = 0.48, color = { 130, 82, 210 }, attack = "single", damageType = "physical", air = false, armorPierce = 0.18, shredBase = 0.15, shredPerLevel = 0.025,
		branches = {
			{ name = text("Caçador de elites", "Elite Hunter"), description = text("Ataca muito mais rápido contra grandes ameaças.", "Strikes faster against major threats."), mods = { mul("interval", 0.7), set("bossDamage", 0.45) } },
			{ name = text("Garras de ônix", "Onyx Claws"), description = text("Reduz a armadura para toda a equipe.", "Shreds armor for the entire team."), mods = { set("armorPierce", 0.45), set("armorShred", 0.25) } },
		},
	},
	hulk = {
		id = "hulk", rarity = "epic", ability = "hulkSmash",
		name = text("Pedregulho", "Boulder"), role = text("Dano de área terrestre", "Ground area damage"), cost = 450,
		description = text("Pancadas pesadas destroem grupos no chão.", "Heavy ground strikes devastate clustered enemies."),
		damage = 34, range = 24, interval = 1.6, color = { 226, 128, 56 }, attack = "splash", damageType = "physical", air = false, splash = 8,
		branches = {
			{ name = text("Cratera gama", "Gamma Crater"), description = text("Impactos atingem áreas maiores.", "Impacts strike a larger area."), mods = { set("splash", 15) } },
			{ name = text("Esmagador", "Armor Smasher"), description = text("Golpes atravessam a proteção inimiga.", "Strikes break through enemy protection."), mods = { set("armorPierce", 0.7), set("armorShred", 0.12) } },
		},
	},
	vision = {
		id = "vision", rarity = "epic", ability = "phaseShift",
		name = text("Prisma", "Prism"), role = text("Feixe que atravessa alinhados", "Beam through lined-up enemies"), cost = 480,
		description = text("Um feixe solar atravessa inimigos alinhados.", "A solar beam pierces enemies standing in a line."),
		damage = 44, range = 30, interval = 1.3, color = { 150, 200, 255 }, attack = "beam", damageType = "tech", air = true, beamWidth = 3,
		branches = {
			{ name = text("Feixe penetrante", "Piercing Beam"), description = text("Feixe mais largo ignora parte da armadura.", "A wider beam ignores part of enemy armor."), mods = { set("beamWidth", 6), set("armorPierce", 0.6) } },
			{ name = text("Concentração solar", "Solar Focus"), description = text("Disparos mais frequentes e concentrados.", "More frequent, concentrated beams."), mods = { mul("interval", 0.55) } },
		},
	},
	warmachine = {
		id = "warmachine", rarity = "epic", ability = "bombardment",
		name = text("Bigorna", "Anvil"), role = text("Artilharia pesada em área", "Heavy area artillery"), cost = 520,
		description = text("Artilharia pesada: mísseis e canhões que atingem grandes áreas.", "Heavy artillery: missiles and cannons that strike wide areas."),
		damage = 27, range = 28, interval = 1.4, color = { 200, 130, 70 }, attack = "splash", damageType = "tech", air = true, splash = 10,
		branches = {
			{ name = text("Salva de mísseis", "Missile Salvo"), description = text("Explosões enormes e mais dano.", "Huge blasts and more damage."), mods = { set("splash", 13), mul("damage", 1.2) } },
			{ name = text("Canhão de ombro", "Shoulder Cannon"), description = text("Tiro devastador que perfura armadura.", "A devastating shot that pierces armor."), mods = { mul("damage", 2), set("armorPierce", 0.5) } },
		},
	},
	starlord = {
		id = "starlord", rarity = "epic", ability = "awesomeMix",
		name = text("Cometa", "Comet"), role = text("Rajadas rápidas de blasters", "Rapid blaster fire"), cost = 430,
		description = text("Blasters gêmeos disparam em rajadas muito rápidas.", "Twin blasters fire in very rapid bursts."),
		pickup = 14, damage = 16, range = 25, interval = 0.32, color = { 40, 150, 170 }, attack = "single", damageType = "tech", air = true,
		branches = {
			{ name = text("Blasters gêmeos", "Twin Blasters"), description = text("Cadência ainda maior.", "An even higher fire rate."), mods = { mul("interval", 0.7) } },
			{ name = text("Granada de gravidade", "Gravity Grenade"), description = text("Explosões em área que desaceleram.", "Area blasts that slow."), mods = { set("attack", "splash"), set("splash", 9), set("slow", 0.3) } },
		},
	},
	groot = {
		id = "groot", rarity = "epic", ability = "rootWall",
		name = text("Carvalho", "Oakheart"), role = text("Controle e dano em área terrestre", "Ground control and area damage"), cost = 420,
		description = text("Raízes prendem grupos inteiros no chão.", "Roots pin entire groups to the ground."),
		damage = 19, range = 23, interval = 1.5, color = { 130, 100, 62 }, attack = "splash", damageType = "physical", air = false, splash = 10, slow = 0.3,
		branches = {
			{ name = text("Raízes profundas", "Deep Roots"), description = text("Área maior e prisão mais forte.", "A larger area and a firmer hold."), mods = { set("slow", 0.5), set("splash", 13) } },
			{ name = text("Colosso", "Colossus"), description = text("Golpes muito mais fortes que rompem armadura.", "Far stronger strikes that break armor."), mods = { mul("damage", 2.2), set("armorShred", 0.1) } },
		},
	},
	--- Legendary --------------------------------------------------------------
	thor = {
		id = "thor", rarity = "legendary", ability = "thunderCall",
		name = text("Brontus", "Brontus"), role = text("Relâmpagos encadeados e defesa aérea", "Chain lightning, air defense"), cost = 550,
		description = text("Relâmpagos saltam entre infectados, inclusive voadores.", "Lightning jumps between infected enemies, including flyers."),
		damage = 32, range = 26, interval = 1.5, color = { 76, 132, 236 }, attack = "chain", damageType = "magic", air = true, chain = 4,
		branches = {
			{ name = text("Tempestade", "Thunderstorm"), description = text("Relâmpagos saltam por mais inimigos.", "Lightning jumps through more enemies."), mods = { set("chain", 8) } },
			{ name = text("Fúria do trovão", "Thunder Fury"), description = text("Concentra o trovão em alvos resistentes.", "Concentrates thunder on resilient targets."), mods = { set("chain", 2), mul("damage", 2.4) } },
		},
	},
	wanda = {
		id = "wanda", rarity = "legendary", ability = "hexBind",
		name = text("Rubi", "Ruby"), role = text("Dano mágico persistente em área", "Persistent magic area damage"), cost = 650,
		description = text("Magia do caos deixa uma zona de dano persistente.", "Chaos magic leaves a persistent damage zone."),
		damage = 34, range = 26, interval = 1.8, color = { 210, 70, 160 }, attack = "dot", damageType = "magic", air = true, splash = 8, dotDuration = 3,
		branches = {
			{ name = text("Domínio do caos", "Chaos Domain"), description = text("Expande a zona de magia persistente.", "Expands the persistent magic zone."), mods = { set("splash", 13) } },
			{ name = text("Ruína rubi", "Ruby Ruin"), description = text("Inimigos expostos sofrem mais dano.", "Exposed enemies suffer more damage."), mods = { mul("damage", 1.5), set("dotDuration", 5) } },
		},
	},
	strange = {
		id = "strange", rarity = "legendary", ability = "dimensionalSlow",
		name = text("Arcano", "Arcanus"), role = text("Controle espacial e suporte mágico", "Spatial control, magic support"), cost = 560,
		description = text("Portais atrasam inimigos e fortalecem aliados mágicos.", "Portals delay enemies and strengthen magic allies."),
		damage = 36, range = 28, interval = 1.5, color = { 120, 80, 200 }, attack = "splash", damageType = "magic", air = true, splash = 9, slow = 0.2, support = true, supportBoost = 0.06,
		branches = {
			{ name = text("Laço dimensional", "Dimensional Loop"), description = text("Portais reposicionam inimigos comuns, com recarga própria.", "Portals reposition ordinary enemies with a separate cooldown."), mods = { set("portal", true), set("slow", 0.35) } },
			{ name = text("Artes místicas", "Mystic Arts"), description = text("Amplifica torres mágicas próximas.", "Amplifies nearby magic towers."), mods = { set("supportBoost", 0.22), add("range", 4) } },
		},
	},
	ghostrider = {
		id = "ghostrider", rarity = "legendary", ability = "hellfire",
		name = text("Cavaleiro Brasa", "Ember Rider"), role = text("Fogo fantasma persistente", "Persistent spirit fire"), cost = 620,
		description = text("Chamas infernais queimam tudo que atravessa a zona.", "Spirit Fire burns everything that crosses the zone."),
		damage = 28, range = 26, interval = 1.4, color = { 255, 128, 44 }, attack = "dot", damageType = "magic", air = false, splash = 8, dotDuration = 4,
		branches = {
			{ name = text("Chamas fantasmas", "Ghost Flames"), description = text("Área muito maior e queima por mais tempo.", "A much larger area that burns longer."), mods = { set("splash", 13), set("dotDuration", 6) } },
			{ name = text("Olhar ardente", "Burning Gaze"), description = text("Dano imenso contra chefes.", "Immense damage against bosses."), mods = { mul("damage", 2), set("bossDamage", 0.6) } },
		},
	},
	--- Mythic ---------------------------------------------------------------
	captainmarvel = {
		id = "captainmarvel", rarity = "mythic", ability = "photonNova",
		name = text("Solaria", "Solaria"), role = text("Feixe cósmico devastador", "Devastating cosmic beam"), cost = 780,
		description = text("Energia fotônica em um feixe largo que varre a linha inteira.", "Photon energy in a wide beam that sweeps the whole line."),
		damage = 68, range = 30, interval = 1.5, color = { 255, 196, 72 }, attack = "beam", damageType = "tech", air = true, beamWidth = 4,
		branches = {
			{ name = text("Pulso fotônico", "Photon Pulse"), description = text("Feixe enorme e mais dano.", "An enormous beam and more damage."), mods = { set("beamWidth", 8), mul("damage", 1.2) } },
			{ name = text("Forma estelar", "Star Form"), description = text("Dispara o dobro de vezes.", "Fires twice as often."), mods = { mul("interval", 0.5) } },
		},
	},
	silversurfer = {
		id = "silversurfer", rarity = "mythic", ability = "cosmicSmite",
		name = text("Órbita", "Orbit"), role = text("Energia cósmica encadeada", "Chained cosmic energy"), cost = 800,
		description = text("Energia cósmica salta por vários inimigos, terrestres ou voadores.", "Cosmic energy leaps between many enemies, ground or air."),
		damage = 34, range = 32, interval = 1.2, color = { 176, 154, 255 }, attack = "chain", damageType = "magic", air = true, chain = 5,
		branches = {
			{ name = text("Onda cósmica", "Cosmic Wave"), description = text("A energia salta por muitos inimigos.", "The energy leaps through many enemies."), mods = { set("chain", 10) } },
			{ name = text("Poder cósmico", "Cosmic Power"), description = text("Concentra tudo em poucos alvos.", "Concentrates everything on a few targets."), mods = { set("chain", 3), mul("damage", 2.5) } },
		},
	},
}

Catalog.MapOrder = { "manhattan", "gamma", "hydra", "wakanda", "latveria" }
Catalog.Maps = {
	manhattan = {
		id = "manhattan", difficulty = 1.0, name = text("Ruas de Manhattan", "Streets of Manhattan"), chapter = 1, bossId = "lizard", color = { 52, 79, 105 },
		description = text("Defenda o núcleo de Manhattan entre ruas e arranha-céus.", "Defend Manhattan's core between streets and skyscrapers."),
		paths = { { { -92, -60 }, { -40, -60 }, { -40, -15 }, { 32, -15 }, { 32, 35 }, { -24, 35 }, { -24, 66 }, { 88, 66 } } },
	},
	gamma = {
		id = "gamma", difficulty = 1.0, name = text("Complexo Gama", "Gamma Complex"), chapter = 2, bossId = "abomination", color = { 57, 100, 64 },
		description = text("Duas entradas contaminadas convergem para o reator.", "Two contaminated entrances converge at the reactor."),
		hazard = { kind = "frenzy", every = 40, warn = 3, duration = 6, color = { 120, 230, 90 },
			name = text("Surto tóxico", "Toxic surge"), hint = text("os infectados correm mais por 6 s", "the infected run faster for 6 s") },
		paths = { { { -92, -72 }, { -60, -72 }, { -60, -20 }, { 0, -20 }, { 0, 25 }, { -55, 25 }, { -55, 70 }, { 0, 70 }, { 0, 90 } }, { { 92, -72 }, { 60, -72 }, { 60, -20 }, { 0, -20 }, { 0, 25 }, { 55, 25 }, { 55, 70 }, { 0, 70 }, { 0, 90 } } },
	},
	hydra = {
		id = "hydra", difficulty = 1.0, name = text("Fundição Sombria", "Shadow Foundry"), chapter = 3, bossId = "redskull", color = { 72, 87, 74 },
		description = text("Rotas alternadas exigem reposicionar sua estratégia.", "Alternating routes demand a flexible strategy."),
		hazard = { kind = "stun", every = 45, warn = 3, duration = 3, radius = 16, color = { 255, 140, 50 },
			name = text("Forno superaquecido", "Overheated furnace"), hint = text("torres no círculo ficam atordoadas", "towers in the circle get stunned"), warning = text("FORNO!", "FURNACE!") },
		paths = { { { -92, -76 }, { -65, -76 }, { -65, 50 }, { -25, 50 }, { -25, -42 }, { 18, -42 }, { 18, 76 }, { 88, 76 } }, { { 92, -76 }, { 60, -76 }, { 60, 12 }, { 18, 12 }, { 18, 76 }, { 88, 76 } } },
	},
	wakanda = {
		id = "wakanda", difficulty = 1.0, name = text("Selva de Cristal", "Crystal Jungle"), chapter = 4, bossId = "killmonger", color = { 87, 67, 118 },
		description = text("Enfrente escudos de cristal em posições espaçadas.", "Face crystal shields between widely spaced defenses."),
		hazard = { kind = "shield", every = 40, warn = 3, power = 0.15, color = { 170, 120, 255 },
			name = text("Cristais protetores", "Guardian crystals"), hint = text("os inimigos ganham escudo", "enemies gain a shield") },
		paths = { { { -92, 72 }, { -65, 72 }, { -65, -66 }, { 65, -66 }, { 65, 44 }, { -15, 44 }, { -15, -8 }, { 20, -8 } } },
	},
	latveria = {
		id = "latveria", difficulty = 1.0, name = text("Cidadela do Tirano", "Tyrant's Citadel"), chapter = 5, bossId = "doom", color = { 64, 92, 85 },
		description = text("Feche os portais e derrote o exército de Tirano de Ferro.", "Close the portals and defeat Iron Tyrant's army."),
		hazard = { kind = "stun", every = 50, warn = 3, duration = 3, radius = 22, color = { 110, 255, 170 },
			name = text("Selo do Tirano", "Tyrant's seal"), hint = text("torres no círculo param por 3 s", "towers in the circle stop for 3 s"), warning = text("SELO!", "SEAL!") },
		paths = { { { -92, -72 }, { -42, -72 }, { -42, -30 }, { 0, -30 }, { 0, 28 }, { 65, 28 }, { 65, 78 }, { 88, 78 } }, { { 92, -72 }, { 42, -72 }, { 42, -30 }, { 0, -30 }, { 0, 28 }, { 65, 28 }, { 65, 78 }, { 88, 78 } }, { { -92, 72 }, { -42, 72 }, { -42, 28 }, { 0, 28 }, { 65, 28 }, { 65, 78 }, { 88, 78 } } },
	},
}

Catalog.EnemyOrder = { "zombie", "runner", "brute", "armored", "stealth", "flyer", "support", "summoner" }
Catalog.BossOrder = { "lizard", "abomination", "redskull", "killmonger", "doom", "loki" }
Catalog.Enemies = {
	zombie = { id = "zombie", name = text("Infectado", "Infected"), hp = 40, speed = 9.8, leak = 1, reward = 10, armor = 0, air = false, stealth = false, boss = false, color = { 111, 165, 94 } },
	runner = { id = "runner", name = text("Corredor", "Runner"), hp = 29, speed = 16.9, leak = 1, reward = 9, armor = 0, air = false, stealth = false, boss = false, color = { 190, 151, 80 } },
	brute = { id = "brute", name = text("Brutamontes", "Brute"), hp = 172, speed = 7.6, leak = 3, reward = 18, armor = 0.05, air = false, stealth = false, boss = false, color = { 120, 133, 79 } },
	armored = { id = "armored", name = text("Blindado", "Armored"), hp = 101, speed = 9.1, leak = 2, reward = 16, armor = 0.48, air = false, stealth = false, boss = false, color = { 128, 146, 159 } },
	stealth = { id = "stealth", name = text("Camuflado", "Hidden"), hp = 62, speed = 11.9, leak = 2, reward = 13, armor = 0, air = false, stealth = true, boss = false, color = { 136, 101, 175 } },
	flyer = { id = "flyer", name = text("Voador contaminado", "Infected Flyer"), hp = 56, speed = 13.5, leak = 2, reward = 13, armor = 0, air = true, stealth = false, boss = false, color = { 82, 180, 151 } },
	support = { id = "support", name = text("Infectado de suporte", "Infected Support"), hp = 118, speed = 8.5, leak = 3, reward = 18, armor = 0.1, air = false, stealth = false, boss = false, color = { 112, 223, 108 } },
	summoner = { id = "summoner", name = text("Invocador", "Summoner"), hp = 190, speed = 7.4, leak = 4, reward = 22, armor = 0.12, air = false, stealth = false, boss = false, color = { 170, 84, 205 } },
	lizard = { id = "lizard", name = text("Gekko Colosso", "Colossal Gecko"), hp = 1962, speed = 7.5, leak = 35, reward = 100, armor = 0.12, air = false, stealth = false, boss = true, color = { 113, 205, 85 }, hint = text("Concentre dano para interromper a regeneração.", "Focus your damage to interrupt regeneration.") },
	abomination = { id = "abomination", name = text("Megabruto infectado", "Infected Megabrute"), hp = 2314, speed = 6.9, leak = 40, reward = 110, armor = 0.2, air = false, stealth = false, boss = true, color = { 174, 167, 86 }, hint = text("Impactos anunciados interrompem torres próximas.", "Telegraphed impacts interrupt nearby towers.") },
	redskull = { id = "redskull", name = text("Comandante Sombra", "Shadow Commander"), hp = 2114, speed = 8.0, leak = 40, reward = 110, armor = 0.18, air = false, stealth = false, boss = true, color = { 226, 71, 63 }, hint = text("Soldados próximos recebem o bônus de comando.", "Nearby soldiers receive a command boost.") },
	killmonger = { id = "killmonger", name = text("Rei Saqueador infectado", "Infected Raider King"), hp = 2466, speed = 8.4, leak = 45, reward = 120, armor = 0.3, air = false, stealth = false, boss = true, color = { 212, 166, 71 }, hint = text("A descarga de cristal é anunciada antes do impacto.", "The crystal discharge is telegraphed before impact.") },
	loki = { id = "loki", name = text("Mestre das Ilusões", "Illusion Master"), hp = 2640, speed = 8.2, leak = 48, reward = 125, armor = 0.22, air = false, stealth = false, boss = true, color = { 82, 196, 104 }, hint = text("Ilusões temporárias confundem as torres; elas somem sozinhas e não dão recompensa.", "Temporary illusions distract your towers; they fade on their own and give no reward.") },
	-- Loki's decoys: never in a wave pool, never worth anything, gone in seconds.
	illusion = { id = "illusion", name = text("Ilusão do Mestre", "Master's Illusion"), hp = 70, speed = 9.5, leak = 0, reward = 0, armor = 0, air = false, stealth = false, boss = false, color = { 120, 230, 140 }, illusion = true },
	doom = { id = "doom", name = text("Tirano de Ferro", "Iron Tyrant"), hp = 2818, speed = 7.5, leak = 50, reward = 130, armor = 0.28, air = false, stealth = false, boss = true, color = { 87, 220, 126 }, hint = text("Armadura, magia e portais mudam a cada fase.", "Armor, magic and portals change with each phase.") },
}


--==============================================================================
-- Modes
--==============================================================================
-- Each campaign map has its own length (Catalog.CampaignWaves); cards run 50
-- waves on the Gamma Complex; the competitive arena never ends. A boss walks in
-- every tenth wave, and a campaign's last wave is that map's own final boss.
-- Training is 12 waves (about seven minutes) with a simplified boss. The old casual endless mode is
-- gone: competitive is the one endless mode.
Catalog.PortalOrder = { "tutorial", "normal", "ranked", "cards" }
Catalog.CampaignWaves = { manhattan = 40, gamma = 50, hydra = 50, wakanda = 50, asgard = 50, latveria = 70 }
-- Each entrance is an authored destination, with a fixed map and ruleset.
-- The lobby is the Heroes' HQ island (hub at 0, 480; WorldBuilder LAYOUT):
-- three campaign stations on the terrace south of the hub, the competitive
-- arena east of it, and the three island extensions: Wakanda and Asgard on
-- the west island, the final expedition (Latveria) on the east island,
-- training and cards on the academy island to the north. facing turns a
-- station about Y; 0 faces +Z. Every station faces the way players arrive.
Catalog.DestinationOrder = { "normal", "normal_gamma", "normal_hydra", "normal_wakanda", "normal_asgard", "normal_latveria",
	"ranked", "ranked_wakanda", "ranked_latveria", "cards", "training" }
Catalog.Destinations = {
	normal = {modeId="normal",mapId="manhattan",x=-42,z=369,district="center"},
	normal_gamma = {modeId="normal",mapId="gamma",x=0,z=363,district="center"},
	normal_hydra = {modeId="normal",mapId="hydra",x=42,z=369,district="center"},
	normal_wakanda = {modeId="normal",mapId="wakanda",x=-232,z=543,facing=math.pi/2,district="expedition"},
	normal_asgard = {modeId="normal",mapId="asgard",x=-232,z=579,facing=math.pi/2,district="expedition"},
	normal_latveria = {modeId="normal",mapId="latveria",x=234,z=595,facing=-math.pi/2,district="expedition"},
	ranked = {modeId="ranked",mapId="hydra",x=112,z=447,facing=-math.pi/2,district="arena"},
	ranked_wakanda = {modeId="ranked",mapId="wakanda",x=112,z=480,facing=-math.pi/2,district="arena"},
	ranked_latveria = {modeId="ranked",mapId="latveria",x=112,z=513,facing=-math.pi/2,district="arena"},
	cards = {modeId="cards",mapId="gamma",x=18,z=733,facing=math.pi,district="special"},
	training = {modeId="tutorial",mapId="manhattan",x=-18,z=733,facing=math.pi,district="special"},
}
-- AFK farm: standing in one of these lobby chambers pays a small amount every
-- minute, measured and paid by the server. Deliberately far below playing:
-- a campaign victory is worth 2,000 Gold for 30-45 minutes.
Catalog.AfkOrder = { "gold", "xp" }
Catalog.Afk = {
	interval = 60,
	gold = { id = "gold", gold = 5, xp = 0, x = -112, z = 453, color = { 255, 206, 82 },
		name = text("Farm de Ouro AFK", "AFK Gold Farm"), rate = text("+5 OURO POR MINUTO", "+5 GOLD PER MINUTE") },
	xp = { id = "xp", gold = 0, xp = 10, x = -112, z = 503, color = { 120, 200, 255 },
		name = text("Farm de XP AFK", "AFK XP Farm"), rate = text("+10 XP POR MINUTO", "+10 XP PER MINUTE") },
}
Catalog.Maps.asgard = {
	id="asgard",difficulty=1,name=text("Ponte Celeste","Sky Bridge"),chapter=6,bossId="loki",color={220,184,96},
	description=text("Defenda a ponte dourada contra uma invasão sem fim. As curvas recompensam alcance e controle.","Defend the golden bridge against an endless invasion. Its bends reward range and control."),
	paths={{{-92,-80},{-60,-80},{-60,-40},{50,-40},{50,0},{-50,0},{-50,40},{60,40},{60,80},{88,80}}},
	hazard = { kind = "push", every = 35, warn = 2, power = 10, color = { 150, 220, 255 },
		name = text("Rajada celeste", "Sky gust"), hint = text("o vento empurra os inimigos para trás!", "the wind pushes enemies back!") },
}
table.insert(Catalog.MapOrder,"asgard")
Catalog.ModeOrder = { "tutorial", "normal", "ranked", "cards" }
Catalog.Modes = {
	tutorial = { id = "tutorial", name = text("Treinamento", "Training"), waves = 12, hpMultiplier = 0.6, rewardMultiplier = 1,
		description = text("Aprenda o básico em 12 ondas, com um chefe simplificado no fim.", "Learn the basics in 12 waves, with a simplified boss at the end.") },
	normal = { id = "normal", name = text("Campanha", "Campaign"), waves = 50, hpMultiplier = 1.2, rewardMultiplier = 1,
		description = text("Cada mapa tem sua duração: 40 a 70 ondas. Chefe a cada 10; o último é o chefe do mapa.", "Each map has its own length: 40 to 70 waves. A boss every 10; the last one is the map's own boss.") },
	ranked = { id = "ranked", name = text("Competitivo", "Competitive"), waves = 0, hpMultiplier = 1.45, rewardMultiplier = 1.5,
		description = text("Ondas sem fim. Sobreviva o máximo que puder e suba no placar da temporada!", "Endless waves. Survive as long as you can and climb the season leaderboard!") },
	cards = { id = "cards", name = text("Roguelike de Cartas", "Card Roguelike"), waves = 50, hpMultiplier = 1.6, rewardMultiplier = 1.25, cards = true,
		description = text("Depois das ondas 5, 10 … 45 escolha 1 de 3 cartas que mudam seu jogo. 50 ondas.", "After waves 5, 10 … 45 pick 1 of 3 cards that change your run. 50 waves.") },
}

--==============================================================================
-- Abilities
--==============================================================================
-- One per hero. kind decides what the server does; the numbers below are the
-- rank-1 values and grow with AbilityRanks.growth. unit says how power reads:
-- pct is a fraction shown as a percentage, the rest are shown as they are.
--   target: "area" needs a point on the map, "tower" one of your towers, "self" nothing.
Catalog.AbilityRanks = {
	max = 5,
	-- Gold to reach rank N, before the hero's rarity multiplier. Rank 1 is free.
	cost = { 0, 300, 700, 1500, 3000 },
	-- Hero mastery level required to reach rank N.
	mastery = { 1, 3, 6, 10, 15 },
	growth = { power = 0.18, duration = 0.10, radius = 0.05, cooldown = -0.04 },
}
Catalog.AbilityOrder = {
	"repulsorBarrage", "deadeye", "airCommand", "ambush",
	"webField", "widowBite", "growth", "swarmSting", "salvage", "radarSense", "tenRings",
	"vibraniumShield", "wakandaForever", "hulkSmash", "phaseShift", "bombardment", "awesomeMix", "rootWall",
	"thunderCall", "hexBind", "dimensionalSlow", "hellfire",
	"photonNova", "cosmicSmite",
}
local function ability(id, kind, target, cooldown, fields, name, description)
	fields.id, fields.kind, fields.target, fields.cooldown = id, kind, target, cooldown
	fields.name, fields.description = name, description
	return fields
end
Catalog.Abilities = {
	repulsorBarrage = ability("repulsorBarrage", "blast", "area", 55, { power = 0.35, radius = 22, unit = "pct", color = { 255, 90, 70 } },
		text("Rajada de Plasma", "Plasma Barrage"), text("Rajada em área: {power}% da vida máxima de cada inimigo em {radius} studs.", "Area barrage: {power}% of each enemy's max health within {radius} studs.")),
	deadeye = ability("deadeye", "execute", "area", 50, { power = 0.22, radius = 14, unit = "pct", color = { 190, 120, 255 } },
		text("Tiro Mortal", "Deadeye"), text("Elimina inimigos comuns com menos de {power}% de vida em {radius} studs. Chefes sofrem dano menor.", "Eliminates ordinary enemies below {power}% health within {radius} studs. Bosses take less.")),
	airCommand = ability("airCommand", "rally", "self", 60, { power = 0.25, duration = 8, stat = "speed", unit = "pct", color = { 255, 110, 110 } },
		text("Comando Aéreo", "Air Command"), text("Todas as suas torres atacam {power}% mais rápido por {duration} s.", "All your towers attack {power}% faster for {duration} s.")),
	ambush = ability("ambush", "stun", "area", 55, { duration = 2.2, radius = 16, unit = "pct", color = { 150, 170, 190 } },
		text("Emboscada", "Ambush"), text("Paralisa inimigos por {duration} s em {radius} studs. Chefes resistem.", "Stuns enemies for {duration} s within {radius} studs. Bosses resist.")),
	webField = ability("webField", "slow", "area", 60, { power = 0.5, duration = 5, radius = 28, unit = "pct", color = { 240, 240, 250 } },
		text("Rede Gigante", "Giant Net"), text("Desacelera inimigos em {power}% por {duration} s em {radius} studs.", "Slows enemies by {power}% for {duration} s within {radius} studs.")),
	widowBite = ability("widowBite", "reveal", "area", 55, { power = 0.2, duration = 9, radius = 30, unit = "pct", color = { 255, 80, 90 } },
		text("Marca da Sombra", "Shade's Mark"), text("Revela camuflados e faz alvos sofrerem +{power}% de dano por {duration} s em {radius} studs.", "Reveals hidden enemies and makes targets take +{power}% damage for {duration} s within {radius} studs.")),
	growth = ability("growth", "overdrive", "tower", 45, { power = 0.5, duration = 8, unit = "pct", color = { 255, 150, 90 } },
		text("Partículas Quânticas", "Quantum Particles"), text("Uma torre sua ataca {power}% mais rápido por {duration} s.", "One of your towers attacks {power}% faster for {duration} s.")),
	swarmSting = ability("swarmSting", "chain", "area", 50, { power = 0.16, count = 6, radius = 40, unit = "pct", color = { 255, 220, 80 } },
		text("Enxame Elétrico", "Electric Swarm"), text("Ferroa {count} inimigos: {power}% da vida máxima de cada um.", "Stings {count} enemies: {power}% of each one's max health.")),
	salvage = ability("salvage", "energy", "self", 60, { power = 0.6, unit = "pct", color = { 120, 220, 255 } },
		text("Sucata Valiosa", "Valuable Scrap"), text("Recebe Ouro da partida na hora: {power}% de uma onda inteira de renda.", "Gain match Gold at once: {power}% of a full wave's income.")),
	radarSense = ability("radarSense", "reveal", "area", 70, { power = 0.12, duration = 14, radius = 45, unit = "pct", color = { 255, 60, 60 } },
		text("Sentido Radar", "Radar Sense"), text("Revela camuflados por {duration} s e marca alvos (+{power}% de dano) em {radius} studs.", "Reveals hidden enemies for {duration} s and marks targets (+{power}% damage) within {radius} studs.")),
	tenRings = ability("tenRings", "pull", "area", 55, { power = 26, radius = 24, unit = "studs", color = { 255, 170, 60 } },
		text("Anéis Celestes", "Sky Rings"), text("Empurra inimigos {power} studs para trás na rota em {radius} studs. Chefes não são afetados.", "Pushes enemies {power} studs back along the path within {radius} studs. Bosses are unaffected.")),
	vibraniumShield = ability("vibraniumShield", "barrier", "self", 90, { power = 20, duration = 10, unit = "hp", color = { 90, 150, 255 } },
		text("Escudo Égide", "Aegis Shield"), text("Um escudo absorve {power} de dano à base por {duration} s.", "A shield absorbs {power} core damage for {duration} s.")),
	wakandaForever = ability("wakandaForever", "heal", "self", 100, { power = 14, unit = "hp", color = { 170, 120, 255 },
		extras = { { kind = "barrier", power = 10, duration = 8 } } },
		text("Garra da Noite", "Night Claw"), text("Restaura {power} de vida do núcleo e o protege com um escudo de {e1.power} por {e1.duration} s.", "Restores {power} core health and shields it for {e1.power} over {e1.duration} s.")),
	hulkSmash = ability("hulkSmash", "blast", "area", 60, { power = 0.35, radius = 28, unit = "pct", color = { 110, 220, 80 },
		extras = { { kind = "stun", duration = 1.8 } } },
		text("Pedregulho Esmaga!", "Boulder Smash!"), text("Esmagamento: {power}% da vida máxima de cada inimigo em {radius} studs e paralisa por {e1.duration} s.", "Smash: {power}% of each enemy's max health within {radius} studs and stuns for {e1.duration} s.")),
	phaseShift = ability("phaseShift", "weaken", "area", 55, { power = 0.45, duration = 10, radius = 40, unit = "pct", color = { 255, 210, 90 },
		extras = { { kind = "reveal", power = 0.15, duration = 10 } } },
		text("Fase Densa", "Phase Shift"), text("Reduz a armadura dos inimigos em {power}% por {duration} s em {radius} studs e os marca (+{e1.power}% de dano).", "Reduces enemy armor by {power}% for {duration} s within {radius} studs and marks them (+{e1.power}% damage).")),
	bombardment = ability("bombardment", "blast", "area", 65, { power = 0.28, radius = 42, unit = "pct", color = { 200, 210, 225 } },
		text("Bombardeio", "Bombardment"), text("Bombardeio: {power}% da vida máxima de cada inimigo em {radius} studs.", "Bombardment: {power}% of each enemy's max health within {radius} studs.")),
	awesomeMix = ability("awesomeMix", "rally", "self", 65, { power = 0.25, duration = 9, stat = "damage", unit = "pct", color = { 255, 90, 140 } },
		text("Batida Cósmica", "Cosmic Beat"), text("Todas as suas torres causam {power}% mais dano por {duration} s.", "All your towers deal {power}% more damage for {duration} s.")),
	rootWall = ability("rootWall", "stun", "area", 60, { duration = 3, radius = 22, unit = "pct", color = { 150, 200, 90 },
		extras = { { kind = "slow", power = 0.5, duration = 5 } } },
		text("Muralha de Raízes", "Root Wall"), text("Prende inimigos por {duration} s em {radius} studs e os desacelera em {e1.power}% depois. Chefes resistem.", "Roots enemies for {duration} s within {radius} studs, then slows them {e1.power}%. Bosses resist.")),
	thunderCall = ability("thunderCall", "chain", "area", 75, { power = 0.3, count = 10, radius = 70, unit = "pct", color = { 120, 220, 255 }, ultimate = true,
		extras = { { kind = "stun", duration = 1.5 } } },
		text("Chamado do Trovão", "Thunder Call"), text("ULTIMATE: relâmpagos atingem {count} inimigos ({power}% da vida máxima de cada) e os paralisam por {e1.duration} s.", "ULTIMATE: lightning strikes {count} enemies ({power}% of each one's max health) and stuns them for {e1.duration} s.")),
	hexBind = ability("hexBind", "stun", "area", 80, { duration = 3.5, radius = 34, unit = "pct", color = { 255, 80, 130 }, ultimate = true,
		extras = { { kind = "weaken", power = 0.4, duration = 8 }, { kind = "blast", power = 0.2 } } },
		text("Feitiço Rubi", "Hex Bind"), text("ULTIMATE: a realidade se dobra. Paralisa por {duration} s em {radius} studs, derrete {e1.power}% da armadura e causa {e2.power}% da vida máxima. Chefes resistem.", "ULTIMATE: reality bends. Stuns for {duration} s within {radius} studs, melts {e1.power}% of armor and deals {e2.power}% of max health. Bosses resist.")),
	dimensionalSlow = ability("dimensionalSlow", "slow", "area", 85, { power = 0.85, duration = 9, radius = 70, unit = "pct", color = { 255, 180, 80 }, ultimate = true,
		extras = { { kind = "pull", power = 22 } } },
		text("Dilatação do Tempo", "Time Dilation"), text("ULTIMATE: o tempo quase para em {radius} studs. Desacelera {power}% por {duration} s e empurra os inimigos {e1.power} studs para trás.", "ULTIMATE: time nearly stops within {radius} studs. Slows {power}% for {duration} s and pushes enemies {e1.power} studs back.")),
	hellfire = ability("hellfire", "burn", "area", 80, { power = 0.6, duration = 7, radius = 32, unit = "pct", color = { 255, 120, 30 }, ultimate = true,
		extras = { { kind = "slow", power = 0.4, duration = 7 }, { kind = "stun", duration = 1 } } },
		text("Fogo Fantasma", "Spirit Fire"), text("ULTIMATE: o inferno engole a zona. Queima {power}% da vida máxima em {duration} s, atordoa por {e2.duration} s e desacelera em {e1.power}%.", "ULTIMATE: hell swallows the zone. Burns {power}% of max health over {duration} s, stuns for {e2.duration} s and slows by {e1.power}%.")),
	photonNova = ability("photonNova", "blast", "area", 90, { power = 0.6, radius = 60, unit = "pct", color = { 255, 210, 90 }, ultimate = true,
		extras = { { kind = "stun", duration = 2.5 }, { kind = "reveal", power = 0.25, duration = 10 } } },
		text("Nova Fotônica", "Photon Nova"), text("ULTIMATE: uma nova varre quase o mapa todo. {power}% da vida máxima de cada inimigo em {radius} studs, paralisa por {e1.duration} s e marca os alvos (+{e2.power}% de dano). Chefes sofrem bem menos.", "ULTIMATE: a nova sweeps nearly the whole map. {power}% of each enemy's max health within {radius} studs, stuns for {e1.duration} s and marks targets (+{e2.power}% damage). Bosses take far less.")),
	cosmicSmite = ability("cosmicSmite", "smite", "self", 90, { power = 0.95, unit = "pct", color = { 200, 225, 255 }, ultimate = true,
		extras = { { kind = "chain", power = 0.35, count = 6, radius = 200 }, { kind = "weaken", power = 0.4, duration = 8, radius = 200 } } },
		text("Julgamento Cósmico", "Cosmic Smite"), text("ULTIMATE: destrói o inimigo mais forte ({power}% da vida máxima), fulmina outros {e1.count} em todo o mapa ({e1.power}% cada) e derrete {e2.power}% da armadura de todos por {e2.duration} s. Chefes sofrem bem menos.", "ULTIMATE: destroys the strongest enemy ({power}% of its max health), strikes {e1.count} more across the whole map ({e1.power}% each) and melts {e2.power}% of everyone's armor for {e2.duration} s. Bosses take far less.")),
}

--==============================================================================
-- Rewards: reasons to come back
--==============================================================================
-- Four small loops around the main game. None of them can be bought, and each
-- is bounded per day, so they make a return visit worth it without becoming a
-- way to farm. A gift with a chest opens it on the spot, like any other chest.
Catalog.Rewards = {
	-- A free chest every few hours. It never stacks: the point is to come back.
	freeChest = { chestId = "rare", cooldown = 6 * 3600 },
	-- Once per account, for joining the experience's Roblox group (Config.GroupId).
	group = { gold = 750 },
	-- One claim per UTC day. Missing a single day is forgiven; two reset the streak.
	loginGraceDays = 2,
	login = {
		{ gold = 250 }, { gold = 350 }, { gold = 450, xp = 150 }, { gold = 600 },
		{ gold = 800, xp = 300 }, { gold = 1000 }, { gold = 1500, chest = "rare" },
	},
	-- Gifts for time spent in the game today. Time resets with the UTC day.
	playtime = {
		{ minutes = 3, gold = 100 }, { minutes = 10, gold = 200 }, { minutes = 20, gold = 300 },
		{ minutes = 35, gold = 450 }, { minutes = 50, gold = 600 }, { minutes = 75, gold = 900, chest = "rare" },
	},
	-- How many different heroes the account owns. Once, ever.
	collection = {
		{ count = 4, gold = 200 }, { count = 6, gold = 400 }, { count = 9, gold = 700 },
		{ count = 12, gold = 1200, title = { id = "collector", pt = "Colecionador", en = "Collector" } },
		{ count = 15, gold = 2000 }, { count = 18, gold = 3000 }, { count = 21, gold = 4500 },
		{ count = 24, gold = 8000, title = { id = "livingLegend", pt = "Lenda Viva", en = "Living Legend" } },
	},
}

--==============================================================================
-- Commander talents (the level tree)
--==============================================================================
-- One talent point per account level after the first. The tree lives on the
-- screen, not in the world. Every branch stays fully earnable over time.
Catalog.TalentBranches = {
	{ id = "fortune", name = text("FORTUNA", "FORTUNE"), color = { 255, 200, 70 }, nodes = { "roundGold", "killGold", "magnet", "victoryGold" } },
	{ id = "guardian", name = text("GUARDIÃO", "GUARDIAN"), color = { 76, 221, 174 }, nodes = { "baseVitality", "baseRecovery", "lastStand" } },
	{ id = "command", name = text("COMANDO", "COMMAND"), color = { 149, 132, 255 }, nodes = { "startingEnergy", "towerPower", "reach", "skillTempo", "abilityPower" } },
}
Catalog.Talents = {
	roundGold = { short = text("RENDA", "INCOME"), name = text("Renda de defesa", "Defense income"), description = text("+2 Ouro do lobby por onda concluída por ponto.", "+2 lobby Gold per completed wave per point."), maxRank = 5, effect = 2, unit = "gold", icon = "+G" },
	killGold = { short = text("TROFÉU", "TROPHY"), name = text("Coleta de troféus", "Trophy collector"), description = text("+4% no Ouro da partida que cada inimigo derruba, por ponto.", "+4% match Gold dropped by each enemy, per point."), maxRank = 5, parent = "roundGold", requiredRank = 2, effect = 4, unit = "%", icon = "KO" },
	magnet = { short = text("ÍMÃ", "MAGNET"), name = text("Magnetismo", "Magnetism"), description = text("+15% no raio do ímã que puxa o Ouro do chão, por ponto.", "+15% magnet radius for pulling Gold off the ground, per point."), maxRank = 5, parent = "killGold", requiredRank = 2, effect = 15, unit = "%", icon = "MG" },
	victoryGold = { short = text("VITÓRIA", "VICTORY"), name = text("Recompensa de vitória", "Victory bounty"), description = text("+2% no bônus de vitória por ponto. Não altera primeiras vitórias nem compras.", "+2% victory bonus per point. Excludes first-win bonuses and purchases."), maxRank = 10, parent = "magnet", requiredRank = 3, effect = 2, unit = "%", icon = "WIN" },
	baseVitality = { short = text("VIDA", "HEALTH"), name = text("Núcleo reforçado", "Reinforced core"), description = text("+4 vida máxima por ponto. No grupo vale o maior bônus.", "+4 max core HP per point. Highest teammate bonus applies."), maxRank = 5, effect = 4, unit = "HP", icon = "HP" },
	baseRecovery = { short = text("REPARO", "REPAIR"), name = text("Equipe de reparos", "Repair crew"), description = text("Recupera 1 vida por ponto a cada 5 ondas. No grupo vale o maior bônus.", "Restore 1 HP per point every 5 waves. Highest teammate bonus applies."), maxRank = 5, parent = "baseVitality", requiredRank = 2, effect = 1, unit = "HP", icon = "+HP" },
	lastStand = { short = text("RESISTE", "LAST STAND"), name = text("Última resistência", "Last stand"), description = text("Uma vez por partida, com o núcleo abaixo de 30%, recupera 5 de vida por ponto.", "Once per match, with the core below 30%, restore 5 HP per point."), maxRank = 3, parent = "baseRecovery", requiredRank = 2, effect = 5, unit = "HP", icon = "LS" },
	startingEnergy = { short = text("INÍCIO", "HEAD START"), name = text("Preparação tática", "Tactical preparation"), description = text("+20 Ouro da partida inicial por ponto.", "+20 starting match Gold per point."), maxRank = 5, effect = 20, unit = "gold", icon = "G" },
	towerPower = { short = text("DANO", "DAMAGE"), name = text("Formação de elite", "Elite formation"), description = text("+1% dano por ponto, dentro do limite permanente de 15%.", "+1% tower damage per point, within the 15% permanent cap."), maxRank = 5, parent = "startingEnergy", requiredRank = 2, effect = 1, unit = "%", icon = "ATK" },
	reach = { short = text("ALCANCE", "RANGE"), name = text("Visão estratégica", "Strategic vision"), description = text("+1% alcance por ponto, dentro do limite permanente de 10%.", "+1% range per point, within the 10% permanent cap."), maxRank = 5, parent = "towerPower", requiredRank = 2, effect = 1, unit = "%", icon = "RNG" },
	skillTempo = { short = text("RECARGA", "COOLDOWN"), name = text("Resposta rápida", "Rapid response"), description = text("-1% na recarga da habilidade do herói por ponto, respeitando o limite total.", "-1% hero ability cooldown per point, respecting the combined cap."), maxRank = 10, parent = "reach", requiredRank = 3, effect = 1, unit = "%", icon = "CD" },
	abilityPower = { short = text("PODER", "POWER"), name = text("Poder amplificado", "Amplified power"), description = text("+2% de potência da habilidade do herói por ponto.", "+2% hero ability strength per point."), maxRank = 10, parent = "skillTempo", requiredRank = 3, effect = 2, unit = "%", icon = "PWR" },
}

--==============================================================================
-- Cards (the roguelike mode)
--==============================================================================
-- After every fifth wave each commander is offered three cards and takes one.
-- effects are additive stat changes that stack; instant fires once, on pick.
-- Some cards have a price: that is what makes the choice a choice.
Catalog.CardRarityWeight = { common = 60, rare = 30, epic = 10 }
Catalog.CardOrder = {
	"sharpen", "quickDraw", "longSight", "armorBreaker", "wideArea", "supplyDrop",
	"skyHunter", "nightHunter", "coinRain", "income", "fastCharge", "abilityPower",
	"bossSlayer", "medic", "fortify", "discount", "supportRange",
	"glassCannon", "overclock", "bloodPact", "gambler", "tempest", "warChest",
}
local function card(id, rarity, maxStacks, name, description, fields)
	fields.id, fields.rarity, fields.maxStacks, fields.name, fields.description = id, rarity, maxStacks, name, description
	return fields
end
Catalog.Cards = {
	sharpen = card("sharpen", "common", 3, text("Lâminas afiadas", "Sharpened Edges"), text("+10% de dano das suas torres.", "+10% damage on your towers."), { effects = { damage = 0.10 } }),
	quickDraw = card("quickDraw", "common", 3, text("Gatilho rápido", "Quick Draw"), text("+8% de velocidade de ataque.", "+8% attack speed."), { effects = { speed = 0.08 } }),
	longSight = card("longSight", "common", 3, text("Mira de águia", "Eagle Eye"), text("+8% de alcance.", "+8% range."), { effects = { range = 0.08 } }),
	armorBreaker = card("armorBreaker", "common", 2, text("Ruptura de armadura", "Armor Breaker"), text("Ignora mais 10% da armadura inimiga.", "Ignores another 10% of enemy armor."), { effects = { pierce = 0.10 } }),
	wideArea = card("wideArea", "common", 2, text("Cobertura ampliada", "Wide Coverage"), text("+12% de área nos ataques.", "+12% attack area."), { effects = { area = 0.12 } }),
	supplyDrop = card("supplyDrop", "common", 5, text("Suprimentos", "Supply Drop"), text("Receba 350 de Ouro da partida agora.", "Gain 350 match Gold now."), { instant = { energy = 350 } }),
	skyHunter = card("skyHunter", "common", 2, text("Caçador de voadores", "Sky Hunter"), text("+25% de dano contra voadores.", "+25% damage against flyers."), { effects = { airDamage = 0.25 } }),
	nightHunter = card("nightHunter", "common", 2, text("Visão noturna", "Night Vision"), text("+25% de dano contra camuflados.", "+25% damage against hidden enemies."), { effects = { stealthDamage = 0.25 } }),
	coinRain = card("coinRain", "rare", 3, text("Chuva de moedas", "Coin Rain"), text("+15% de Ouro das eliminações.", "+15% Gold from kills."), { effects = { killGold = 0.15 } }),
	income = card("income", "rare", 3, text("Rede logística", "Supply Network"), text("+20% no bônus de Ouro por onda.", "+20% Gold bonus per wave."), { effects = { energyIncome = 0.20 } }),
	fastCharge = card("fastCharge", "rare", 2, text("Recarga rápida", "Fast Recharge"), text("-10% de recarga da sua habilidade.", "-10% ability cooldown."), { effects = { cooldown = 0.10 } }),
	abilityPower = card("abilityPower", "rare", 3, text("Poder amplificado", "Amplified Power"), text("+20% de potência da sua habilidade.", "+20% ability strength."), { effects = { abilityPower = 0.20 } }),
	bossSlayer = card("bossSlayer", "rare", 3, text("Caçador de chefes", "Boss Slayer"), text("+20% de dano contra chefes.", "+20% damage against bosses."), { effects = { bossDamage = 0.20 } }),
	medic = card("medic", "rare", 3, text("Enfermaria", "Field Medic"), text("Restaura 8 de vida do núcleo agora.", "Restore 8 core health now."), { instant = { heal = 8 } }),
	fortify = card("fortify", "rare", 3, text("Núcleo reforçado", "Fortified Core"), text("+10 de vida máxima do núcleo e recupera 10.", "+10 max core health and restore 10."), { instant = { maxHealth = 10, heal = 10 } }),
	discount = card("discount", "rare", 2, text("Contrato de armas", "Arms Contract"), text("Torres custam 8% menos para posicionar.", "Towers cost 8% less to place."), { effects = { discount = 0.08 } }),
	supportRange = card("supportRange", "rare", 2, text("Rede de comando", "Command Network"), text("+15% de alcance nas torres de suporte.", "+15% range on support towers."), { effects = { supportRange = 0.15 } }),
	glassCannon = card("glassCannon", "epic", 2, text("Canhão de vidro", "Glass Cannon"), text("+35% de dano, mas -15% de alcance.", "+35% damage, but -15% range."), { effects = { damage = 0.35, range = -0.15 } }),
	overclock = card("overclock", "epic", 2, text("Sobrecarga", "Overclock"), text("+30% de velocidade de ataque, mas -12% de dano.", "+30% attack speed, but -12% damage."), { effects = { speed = 0.30, damage = -0.12 } }),
	bloodPact = card("bloodPact", "epic", 2, text("Pacto de ouro", "Gold Pact"), text("+40% de Ouro das eliminações, mas -10% de dano.", "+40% Gold from kills, but -10% damage."), { effects = { killGold = 0.40, damage = -0.10 } }),
	gambler = card("gambler", "epic", 3, text("Aposta", "The Gamble"), text("50%: +600 de Ouro. 50%: perde 200.", "50%: +600 Gold. 50%: lose 200."), { instant = { gamble = true } }),
	tempest = card("tempest", "epic", 2, text("Tempestade", "Tempest"), text("+40% de potência da habilidade, mas +15% de recarga.", "+40% ability strength, but +15% cooldown."), { effects = { abilityPower = 0.40, cooldown = -0.15 } }),
	warChest = card("warChest", "epic", 1, text("Cofre de guerra", "War Chest"), text("Receba 900 de Ouro da partida agora.", "Gain 900 match Gold now."), { instant = { energy = 900 } }),
}

--==============================================================================
-- Products (Robux)
--==============================================================================
-- Everything a player can buy with Robux lives in the premium shop, apart from
-- the Gold chest shop. Ids stay in Config.luau; an id of 0 means unavailable.
-- Reinforcements: authored combat stats, two branches and a leader skill each.
local reinforcements = {
	{"wolverine","Presa","Fang","epic",{235,130,40},420,36,16,0.65,"single","physical",false,"claws","execute",0.28,55},
	{"cyclops","Farol","Beacon","rare",{232,80,64},320,38,32,1.35,"beam","tech",true,"visor","blast",0.28,60},
	{"storm","Monção","Monsoon","legendary",{50,180,180},600,40,34,1.4,"chain","magic",true,"cape","chain",0.26,75},
	{"jean","Aurora","Aurora","mythic",{190,110,240},760,44,30,1.3,"splash","magic",true,"phoenix","burn",0.08,80},
	{"iceman","Geada","Frost","rare",{150,200,245},300,17,25,1.05,"splash","magic",false,"ice","slow",0.5,65},
	{"gambit","Ás","Ace","epic",{220,50,70},390,35,29,1.15,"splash","magic",true,"cards","blast",0.32,60},
	{"nightcrawler","Pisca","Blink","rare",{245,205,80},290,24,22,0.8,"single","magic",false,"tail","pull",22,65},
	{"beast","Juba","Mane","rare",{226,170,80},240,26,18,0.95,"splash","physical",false,"fur","stun",0,65},
	{"psylocke","Kunai","Kunai","epic",{200,40,64},400,32,23,0.7,"single","magic",false,"blade","weaken",0.4,65},
	{"deadpool","Confete","Confetti","epic",{240,90,170},380,24,28,0.6,"single","physical",true,"swords","rally",0.2,65},
	{"moonknight","Eclipse","Eclipse","rare",{255,200,90},310,34,25,1.05,"single","physical",true,"moon","reveal",0.18,65},
	{"nova","Pulsar","Pulsar","legendary",{90,200,240},590,48,32,1.05,"beam","tech",true,"nova","blast",0.38,75},
}
for _, row in ipairs(reinforcements) do
	local id, pt, en, rarity, color, cost, damage, range, interval, attack, damageType, air, costume, kind, power, cooldown = unpack(row)
	local skillId = id .. "Power"
	local hero = {id=id,name=text(pt,en),rarity=rarity,color=color,cost=cost,damage=damage,range=range,interval=interval,
		attack=attack,damageType=damageType,air=air,ability=skillId,costume=costume,splash=6,chain=3,beamWidth=3,
		role=text("Reforço "..(damageType=="magic" and "mágico" or "de combate"), damageType=="magic" and "Magic reinforcement" or "Combat reinforcement"),
		description=text("Combine sua especialização com o poder do líder.","Combine your specialization with the leader power."),
		branches={
			{name=text("Potência máxima","Maximum power"),description=text("+65% de dano; perfura armadura.","+65% damage; pierces armor."),mods={mul("damage",1.65),set("armorPierce",0.35)}},
			{name=text("Cobertura tática","Tactical coverage"),description=text("+9 de alcance e ataques 25% mais rápidos.","+9 range and 25% faster attacks."),mods={add("range",9),mul("interval",0.8)}},
		}}
	if id=="iceman" then hero.slow=0.25 end
	if id=="wolverine" or id=="psylocke" then hero.armorPierce=0.25 end
	if id=="moonknight" then hero.reveal=true end
	Catalog.Heroes[id]=hero; table.insert(Catalog.HeroOrder,id)
	local descriptions = {
		blast=text("Explosão: {power}% da vida máxima em {radius} studs. Chefes resistem.","Blast: {power}% max HP within {radius} studs. Bosses resist."),
		execute=text("Finaliza alvos abaixo de {power}% de vida em {radius} studs. Chefes resistem.","Finishes targets below {power}% HP within {radius} studs. Bosses resist."),
		chain=text("Atinge {count} inimigos com {power}% da vida máxima. Chefes resistem.","Hits {count} enemies for {power}% max HP. Bosses resist."),
		burn=text("Zona de energia: {power}% de vida por segundo por {duration} s. Chefes resistem.","Energy zone: {power}% HP per second for {duration} s. Bosses resist."),
		slow=text("Desacelera {power}% por {duration} s em {radius} studs.","Slows {power}% for {duration} s within {radius} studs."),
		pull=text("Recua inimigos {power} studs. Não move chefes.","Pushes enemies back {power} studs. Does not move bosses."),
		stun=text("Paralisa por {duration} s em {radius} studs. Chefes resistem.","Stuns for {duration} s within {radius} studs. Bosses resist."),
		weaken=text("Remove {power}% de armadura por {duration} s.","Removes {power}% armor for {duration} s."),
		rally=text("Suas torres ganham {power}% de dano por {duration} s.","Your towers gain {power}% damage for {duration} s."),
		reveal=text("Revela e marca: +{power}% de dano por {duration} s.","Reveals and marks: +{power}% damage for {duration} s."),
	}
	local names={wolverine=text("Fúria das garras","Claw fury"),cyclops=text("Explosão óptica","Optic blast"),storm=text("Olho da tempestade","Eye of the storm"),jean=text("Chama Aurora","Aurora flame"),iceman=text("Era do gelo","Ice age"),gambit=text("Ás explosivo","Explosive ace"),nightcrawler=text("Puf!","Poof!"),beast=text("Salto selvagem","Wild leap"),psylocke=text("Corte psíquico","Psychic slash"),deadpool=text("Trabalho em equipe","Teamwork"),moonknight=text("Luz da Lua","Moonlight"),nova=text("Supernova","Supernova")}
	Catalog.Abilities[skillId]=ability(skillId,kind,kind=="rally" and "self" or "area",cooldown,
		{power=power,duration=kind=="stun" and 2 or 6,radius=30,count=6,stat="damage",unit=kind=="pull" and "studs" or "pct",color=color,ultimate=rarity=="mythic" or rarity=="legendary"},names[id],descriptions[kind])
	table.insert(Catalog.AbilityOrder,skillId)
end
Catalog.Abilities.stormPower.extras={{kind="stun",duration=1.2}}
Catalog.Abilities.stormPower.description=text("Relâmpagos: {power}% da vida de {count} alvos; paralisa por {e1.duration} s. Chefes resistem.","Lightning: {power}% HP to {count} targets; stuns for {e1.duration} s. Bosses resist.")
Catalog.Abilities.jeanPower.extras={{kind="weaken",power=0.2,duration=6}}
Catalog.Abilities.jeanPower.description=text("Chama: {power}% de vida por segundo por {duration} s; remove {e1.power}% de armadura. Chefes resistem.","Flame: {power}% HP per second for {duration} s; removes {e1.power}% armor. Bosses resist.")
Catalog.Abilities.novaPower.extras={{kind="reveal",power=0.12,duration=6}}
Catalog.Abilities.novaPower.description=text("Explosão: {power}% da vida em {radius} studs; revela e marca (+{e1.power}% dano). Chefes resistem.","Blast: {power}% HP within {radius} studs; reveals and marks (+{e1.power}% damage). Bosses resist.")
local identities={
	wolverine={text("Garras contra elites","Claws against elites"),text("Caçador de chefes","Boss hunter"),{set("bossDamage",0.8),mul("damage",1.25)},text("Frenesi","Frenzy"),{mul("interval",0.55),add("range",3)}},
	cyclops={text("Feixe que atravessa a horda","Beam through the horde"),text("Feixe amplo","Wide beam"),{set("beamWidth",7),mul("damage",1.2)},text("Foco óptico","Optic focus"),{set("armorPierce",0.6),add("range",8)}},
	storm={text("Relâmpagos e defesa aérea","Lightning and air defense"),text("Cadeia de trovões","Thunder chain"),{set("chain",6)},text("Olho do furacão","Hurricane eye"),{mul("damage",1.5),set("slow",0.25)}},
	jean={text("Explosões de energia psíquica","Psychic energy blasts"),text("Asas de fogo","Wings of fire"),{set("splash",12)},text("Fogo concentrado","Focused fire"),{mul("damage",1.5),set("bossDamage",0.45)}},
	iceman={text("Congela o avanço de grupos","Freezes group advances"),text("Nevasca","Blizzard"),{set("splash",11),set("slow",0.35)},text("Zero absoluto","Absolute zero"),{set("slow",0.55),mul("damage",1.35)}},
	gambit={text("Cartas explosivas contra grupos","Explosive cards against groups"),text("Baralho completo","Full deck"),{set("splash",12)},text("Ás de armadura","Armor ace"),{set("armorPierce",0.65),mul("damage",1.3)}},
	nightcrawler={text("Ataques rápidos e recuo tático","Fast attacks and tactical pushback"),text("Espadas gêmeas","Twin swords"),{mul("interval",0.5)},text("Sombra distante","Distant shadow"),{add("range",12),set("reveal",true)}},
	beast={text("Impactos curtos contra hordas","Short-range horde impacts"),text("Salto esmagador","Crushing leap"),{set("splash",10),mul("damage",1.2)},text("Instinto feroz","Fierce instinct"),{mul("interval",0.6),set("armorPierce",0.3)}},
	psylocke={text("Lâminas psíquicas perfurantes","Piercing psychic blades"),text("Lâmina espiritual","Spirit blade"),{set("armorPierce",0.8)},text("Dança psíquica","Psychic dance"),{mul("interval",0.55),add("range",4)}},
	deadpool={text("Rajadas rápidas e apoio ofensivo","Rapid bursts and offensive support"),text("Arsenal duplo","Dual arsenal"),{mul("interval",0.6),add("range",5)},text("Munição explosiva","Explosive rounds"),{set("attack","splash"),set("splash",8)}},
	moonknight={text("Revela camuflados na rota","Reveals cloaked enemies"),text("Vigília lunar","Moon watch"),{add("range",14),set("mark",0.15)},text("Lâminas crescentes","Crescent blades"),{set("attack","chain"),set("chain",3)}},
	nova={text("Feixe cósmico antiaéreo","Cosmic anti-air beam"),text("Corredor estelar","Star corridor"),{set("beamWidth",8),add("range",6)},text("Impacto cósmico","Cosmic impact"),{mul("damage",1.6),set("armorPierce",0.4)}},
}
for id,entry in pairs(identities) do
	local hero=Catalog.Heroes[id]; hero.role=entry[1]; hero.description=entry[1]
	for i=1,2 do
		local name=entry[i==1 and 2 or 4]; local mods=entry[i==1 and 3 or 5]
		local labels={damage=text("dano","damage"),interval=text("intervalo","attack interval"),range=text("alcance","range"),bossDamage=text("bônus contra chefes","boss bonus"),armorPierce=text("perfuração","armor pierce"),beamWidth=text("largura do feixe","beam width"),chain=text("alvos encadeados","chained targets"),slow=text("lentidão","slow"),splash=text("raio de explosão","blast radius"),mark=text("marcação","mark")}
		local lines={pt={},en={}}
		for _,mod in ipairs(mods) do
			for _,lang in ipairs({"pt","en"}) do
				local label=labels[mod.key] and labels[mod.key][lang]
				local value=mod.value
				if label then
					if mod.op=="mul" then value="×"..tostring(value)
					elseif mod.op=="add" then value="+"..tostring(value)
					elseif mod.key=="bossDamage" or mod.key=="armorPierce" or mod.key=="slow" or mod.key=="mark" then value=math.floor(value*100).."%" end
					table.insert(lines[lang],label.." "..tostring(value))
				elseif mod.key=="reveal" then table.insert(lines[lang],lang=="pt" and "revela camuflados" or "reveals hidden enemies")
				elseif mod.key=="attack" then table.insert(lines[lang],lang=="pt" and "ataque em grupo" or "group attacks") end
			end
		end
		hero.branches[i]={name=name,mods=mods,description=text(table.concat(lines.pt," • "),table.concat(lines.en," • "))}
	end
end

-- Personal outposts support the shared core. Income is match Gold, never
-- lobby Gold. Each has five match-only levels, bought with match Gold.
Catalog.BaseOrder={"outpost","workshop","garden","bunker","arsenal","barracks","reactor","citadel","carrier","sanctum","worldtree"}
Catalog.Bases={}
local bases={
	{"outpost","Posto da Resistência","Resistance outpost","common","balanced",{139,213,151},20,0,0,0,0},
	{"workshop","Oficina Volt","Volt workshop","common","farm",{255,193,83},45,4,0,0,0},
	{"garden","Horta de suprimentos","Supply garden","common","farm",{146,213,106},40,8,0,0,0},
	{"bunker","Bunker da Agência","Agency bunker","rare","wall",{108,188,228},20,18,0,120,0},
	{"arsenal","Arsenal Volt","Volt arsenal","rare","turret",{228,116,82},20,8,26,0,0},
	{"barracks","Quartel da Selva","Jungle barracks","epic","soldiers",{190,139,241},25,12,0,0,85},
	{"reactor","Reator de cristal","Crystal reactor","epic","farm",{89,228,194},65,8,0,0,0},
	{"citadel","Cidadela Celeste","Sky citadel","legendary","wall",{255,210,118},28,28,0,240,0},
	{"carrier","Porta-aviões da Resistência","Resistance carrier","legendary","soldiers",{146,183,225},32,14,0,0,140},
	{"sanctum","Santuário Arcano","Arcane sanctum","mythic","turret",{242,142,92},30,14,48,0,0},
	{"worldtree","Jardim da Árvore-Mundo","World-tree garden","mythic","farm",{245,177,221},85,12,0,0,0},
}
local roles={balanced=text("Renda básica e vida ao evoluir.","Basic income and HP when upgraded."),farm=text("Mais Ouro da partida a cada onda concluída.","More match Gold each completed wave."),wall=text("Barricada troca vida por dano e se regenera fora de combate.","Barricade trades HP for damage and regenerates out of combat."),turret=text("Canhão automático protege a chegada ao núcleo.","Automatic cannon guards the approach to the core."),soldiers=text("Soldados percorrem a rota ao contrário e colidem com inimigos.","Soldiers march backwards along the path and collide with enemies.")}
for _,row in ipairs(bases) do
	local id,pt,en,rarity,style,color,income,hp,damage,wall,soldier=unpack(row)
	Catalog.Bases[id]={id=id,name=text(pt,en),rarity=rarity,style=style,color=color,income=income,hp=hp,damage=damage,wall=wall,soldier=soldier,starter=id=="outpost",description=roles[style]}
end
Catalog.BaseUpgradeCosts={450,950,1800,3200}

-- Five price tiers per collection. Existing chest IDs/pity are preserved.
Catalog.HeroChestOrder={"supply","rare","epic","legendary","cosmic"}
Catalog.BaseChestOrder={"base_supply","base_rare","base_epic","base_legendary","base_cosmic"}
Catalog.Chests.supply={id="supply",name=text("Suprimentos","Supplies"),cost=400,color={155,214,129},odds={common=75,rare=23,epic=2,legendary=0,mythic=0}}
Catalog.Chests.epic={id="epic",name=text("Baú Épico","Epic chest"),cost=1500,color={196,145,250},odds={common=0,rare=45,epic=47,legendary=7,mythic=1},pity={after=8,minimum="epic"}}
Catalog.Chests.cosmic={id="cosmic",name=text("Baú Cósmico","Cosmic chest"),cost=5000,color={255,138,198},odds={common=0,rare=0,epic=45,legendary=43,mythic=12},pity={after=15,minimum="mythic"}}
Catalog.ChestOrder={}
for _,id in ipairs(Catalog.HeroChestOrder) do
	local chest=Catalog.Chests[id]; chest.kind="hero"
	chest.description=chest.description or text("Um herói aleatório. Veja as chances antes de abrir.","One random hero. Check the odds before opening.")
	table.insert(Catalog.ChestOrder,id)
	local baseId="base_"..id
	local baseChest={id=baseId,kind="base",name=chest.name,cost=chest.cost,color=chest.color,odds=chest.odds,pity=chest.pity,description=text("Uma base aleatória. Equipe apenas uma no lobby.","One random base. Equip one in the lobby.")}
	Catalog.Chests[baseId]=baseChest
end
for _,id in ipairs(Catalog.BaseChestOrder) do table.insert(Catalog.ChestOrder,id) end

-- Map factions preserve family counters while adding distinct silhouettes.
Catalog.MapEnemyVariants={}
local factions={manhattan={"sinister","Capanga Sombrio","Grim minion",{191,134,99}},gamma={"gamma","Mutante Gama","Gamma mutant",{145,197,86}},hydra={"hydra","Soldado Sombra","Shadow trooper",{88,153,128}},wakanda={"crystal","Saqueador de cristal","Crystal raider",{171,120,201}},latveria={"doombot","Robô do Tirano","Tyrant bot",{118,161,164}}}
for mapId,faction in pairs(factions) do
	Catalog.MapEnemyVariants[mapId]={}
	for _,family in ipairs({"zombie","runner","armored"}) do
		local original=Catalog.Enemies[family]; local variant={}
		for key,value in pairs(original) do variant[key]=value end
		variant.id=faction[1].."_"..family; variant.family=family; variant.faction=faction[1]; variant.color=faction[4]
		variant.name=text(faction[2].." • "..original.name.pt,faction[3].." • "..original.name.en)
		-- Same budget and stats: a visual faction must not silently favor one map.
		Catalog.Enemies[variant.id]=variant; Catalog.MapEnemyVariants[mapId][family]=variant.id
		table.insert(Catalog.EnemyOrder,variant.id)
	end
end

Catalog.Products = {
	Passes = {
		collector = { id = 0, price = 149, name = text("Drone coletor", "Collector Drone"), description = text("Coleta suas moedas automaticamente. Não aumenta o Ouro total.", "Collects your coins automatically. Does not increase total Gold.") },
		training = { id = 0, price = 199, name = text("Treinamento acelerado", "Accelerated Training"), description = text("+25% de XP de conta e de maestria.", "+25% account and mastery XP.") },
		speed3 = { id = 0, price = 149, name = text("Velocidade 3x", "3x Speed"), description = text("Libera 3x nas partidas. A partida acelera quando todo o grupo escolhe 3x.", "Unlocks 3x in matches. The match speeds up when the whole squad picks 3x.") },
		vip = { id = 0, price = 299, name = text("Pacote VIP visual", "VIP Style Pack"), description = text("Título, emote, trilha e aparência especial do drone.", "Title, emote, trail and special drone appearance.") },
	},
	Consumables = {
		gold1000 = { id = 0, price = 79, gold = 1000, name = text("1.000 de Ouro", "1,000 Gold") },
		gold5000 = { id = 0, price = 299, gold = 5000, name = text("5.000 de Ouro", "5,000 Gold") },
		gold12000 = { id = 0, price = 599, gold = 12000, name = text("12.000 de Ouro", "12,000 Gold") },
		gold30000 = { id = 0, price = 1299, gold = 30000, name = text("30.000 de Ouro", "30,000 Gold") },
		-- Once per account: an epic hero and Gold. Bought again (a second
		-- prompt racing the first), it is paid in Gold instead of the hero.
		starterPack = { id = 0, price = 99, gold = 5000, heroId = "hulk", repeatGold = 2500, name = text("Pacote Inicial", "Starter Pack"),
			description = text("Uma vez por conta: Pedregulho (épico) + 5.000 de Ouro.", "Once per account: Boulder (epic) + 5,000 Gold.") },
	},
	-- One product per purchasable hero, priced by rarity. The two starter
	-- heroes are free and never sold.
	Heroes = {},
}
for _, heroId in ipairs(Catalog.HeroOrder) do
	local hero = Catalog.Heroes[heroId]
	if not hero.starter then
		Catalog.Products.Heroes[heroId] = { id = 0, price = Catalog.Rarities[hero.rarity].robux, name = hero.name, rarity = hero.rarity }
	end
end

return Catalog
