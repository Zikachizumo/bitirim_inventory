return {
	-- 0	vehicle has no storage
	-- 1	vehicle has no trunk storage
	-- 2	vehicle has no glovebox storage
	-- 3	vehicle has trunk in the hood
	Storage = {
		[`jester`] = 3,
		[`adder`] = 3,
		[`osiris`] = 1,
		[`pfister811`] = 1,
		[`penetrator`] = 1,
		[`autarch`] = 1,
		[`bullet`] = 1,
		[`cheetah`] = 1,
		[`cyclone`] = 1,
		[`voltic`] = 1,
		[`reaper`] = 3,
		[`entityxf`] = 1,
		[`t20`] = 1,
		[`taipan`] = 1,
		[`tezeract`] = 1,
		[`torero`] = 3,
		[`turismor`] = 1,
		[`fmj`] = 1,
		[`infernus`] = 1,
		[`italigtb`] = 3,
		[`italigtb2`] = 3,
		[`nero2`] = 1,
		[`vacca`] = 3,
		[`vagner`] = 1,
		[`visione`] = 1,
		[`prototipo`] = 1,
		[`zentorno`] = 1,
		[`trophytruck`] = 0,
		[`trophytruck2`] = 0,
	},

	-- slots, maxWeight (gram)
	-- Bitirim: TUM araclarda torpido = 6 slot / 50 KG (50000 g).
	glovebox = {
		[0] = {6, 50000},		-- Compact
		[1] = {6, 50000},		-- Sedan
		[2] = {6, 50000},		-- SUV
		[3] = {6, 50000},		-- Coupe
		[4] = {6, 50000},		-- Muscle
		[5] = {6, 50000},		-- Sports Classic
		[6] = {6, 50000},		-- Sports
		[7] = {6, 50000},		-- Super
		[8] = {6, 50000},		-- Motorcycle
		[9] = {6, 50000},		-- Offroad
		[10] = {6, 50000},		-- Industrial
		[11] = {6, 50000},		-- Utility
		[12] = {6, 50000},		-- Van
		[14] = {6, 50000},		-- Boat
		[15] = {6, 50000},		-- Helicopter
		[16] = {6, 50000},		-- Plane
		[17] = {6, 50000},		-- Service
		[18] = {6, 50000},		-- Emergency
		[19] = {6, 50000},		-- Military
		[20] = {6, 50000},		-- Commercial (trucks)
		models = {
			[`xa21`] = {6, 50000}
		}
	},

	-- Bitirim: TUM araclarda bagaj = 6x6 = 36 slot. Agirlik siniri 999.999 KG
	-- (pratikte sinirsiz). Kilit acma/kapama (arac seviyesi/modeli) sonraki adim.
	trunk = {
		[0] = {36, 999999000},		-- Compact
		[1] = {36, 999999000},		-- Sedan
		[2] = {36, 999999000},		-- SUV
		[3] = {36, 999999000},		-- Coupe
		[4] = {36, 999999000},		-- Muscle
		[5] = {36, 999999000},		-- Sports Classic
		[6] = {36, 999999000},		-- Sports
		[7] = {36, 999999000},		-- Super
		[8] = {36, 999999000},		-- Motorcycle
		[9] = {36, 999999000},		-- Offroad
		[10] = {36, 999999000},	-- Industrial
		[11] = {36, 999999000},	-- Utility
		[12] = {36, 999999000},	-- Van
		[14] = {36, 999999000},	-- Boat
		[15] = {36, 999999000},	-- Helicopter
		[16] = {36, 999999000},	-- Plane
		[17] = {36, 999999000},	-- Service
		[18] = {36, 999999000},	-- Emergency
		[19] = {36, 999999000},	-- Military
		[20] = {36, 999999000},	-- Commercial
		models = {
			[`xa21`] = {36, 999999000}
		},
	}
}
