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
	-- Bitirim: TUM araclarda torpido = 5 slot / 50 KG (50000 g).
	glovebox = {
		[0] = {5, 50000},		-- Compact
		[1] = {5, 50000},		-- Sedan
		[2] = {5, 50000},		-- SUV
		[3] = {5, 50000},		-- Coupe
		[4] = {5, 50000},		-- Muscle
		[5] = {5, 50000},		-- Sports Classic
		[6] = {5, 50000},		-- Sports
		[7] = {5, 50000},		-- Super
		[8] = {5, 50000},		-- Motorcycle
		[9] = {5, 50000},		-- Offroad
		[10] = {5, 50000},		-- Industrial
		[11] = {5, 50000},		-- Utility
		[12] = {5, 50000},		-- Van
		[14] = {5, 50000},		-- Boat
		[15] = {5, 50000},		-- Helicopter
		[16] = {5, 50000},		-- Plane
		[17] = {5, 50000},		-- Service
		[18] = {5, 50000},		-- Emergency
		[19] = {5, 50000},		-- Military
		[20] = {5, 50000},		-- Commercial (trucks)
		models = {
			[`xa21`] = {5, 50000}
		}
	},

	-- Bitirim: TUM araclarda bagaj = 6x6 = 36 slot. Kilit acma/kapama (arac
	-- seviyesi/modeli) sonraki adim. Agirlik simdilik 288 KG (36 * 8 KG),
	-- daha sonra ayarlanabilir.
	trunk = {
		[0] = {36, 288000},		-- Compact
		[1] = {36, 288000},		-- Sedan
		[2] = {36, 288000},		-- SUV
		[3] = {36, 288000},		-- Coupe
		[4] = {36, 288000},		-- Muscle
		[5] = {36, 288000},		-- Sports Classic
		[6] = {36, 288000},		-- Sports
		[7] = {36, 288000},		-- Super
		[8] = {36, 288000},		-- Motorcycle
		[9] = {36, 288000},		-- Offroad
		[10] = {36, 288000},	-- Industrial
		[11] = {36, 288000},	-- Utility
		[12] = {36, 288000},	-- Van
		[14] = {36, 288000},	-- Boat
		[15] = {36, 288000},	-- Helicopter
		[16] = {36, 288000},	-- Plane
		[17] = {36, 288000},	-- Service
		[18] = {36, 288000},	-- Emergency
		[19] = {36, 288000},	-- Military
		[20] = {36, 288000},	-- Commercial
		models = {
			[`xa21`] = {36, 288000}
		},
	}
}
