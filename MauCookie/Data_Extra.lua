-- MauCookie: small tables copied by hand from the original's main.js
-- (version 2.052): milks, backgrounds, Business day names, building buff
-- names, the golden cookie upgrade list, the blab lines, reindeer names.

local _, NS = ...

-- Game.AllMilks: type 0 milks are ranked by achievements (one per 25),
-- type 1 milks need "Fanciful dairy selection".  pic is the image key.
NS.MILKS = {
	{ name = "Automatic", icon = {0,7}, type = -1, pic = "milkPlain" },
	{ name = "Plain milk", icon = {1,8}, type = 0, pic = "milkPlain" },
	{ name = "Chocolate milk", icon = {2,8}, type = 0, pic = "milkChocolate" },
	{ name = "Raspberry milk", icon = {3,8}, type = 0, pic = "milkRaspberry" },
	{ name = "Orange milk", icon = {4,8}, type = 0, pic = "milkOrange" },
	{ name = "Caramel milk", icon = {5,8}, type = 0, pic = "milkCaramel" },
	{ name = "Banana milk", icon = {6,8}, type = 0, pic = "milkBanana" },
	{ name = "Lime milk", icon = {7,8}, type = 0, pic = "milkLime" },
	{ name = "Blueberry milk", icon = {8,8}, type = 0, pic = "milkBlueberry" },
	{ name = "Strawberry milk", icon = {9,8}, type = 0, pic = "milkStrawberry" },
	{ name = "Vanilla milk", icon = {10,8}, type = 0, pic = "milkVanilla" },
	{ name = "Zebra milk", icon = {10,7}, type = 1, pic = "milkZebra" },
	{ name = "Cosmic milk", icon = {9,7}, type = 1, pic = "milkStars" },
	{ name = "Flaming milk", icon = {8,7}, type = 1, pic = "milkFire" },
	{ name = "Sanguine milk", icon = {7,7}, type = 1, pic = "milkBlood" },
	{ name = "Midas milk", icon = {6,7}, type = 1, pic = "milkGold" },
	{ name = "Midnight milk", icon = {5,7}, type = 1, pic = "milkBlack" },
	{ name = "Green inferno milk", icon = {4,7}, type = 1, pic = "milkGreenFire" },
	{ name = "Frostfire milk", icon = {3,7}, type = 1, pic = "milkBlueFire" },
	{ name = "Honey milk", icon = {21,23}, type = 0, pic = "milkHoney" },
	{ name = "Coffee milk", icon = {22,23}, type = 0, pic = "milkCoffee" },
	{ name = "Tea milk", icon = {23,23}, type = 0, pic = "milkTea" },
	{ name = "Coconut milk", icon = {24,23}, type = 0, pic = "milkCoconut" },
	{ name = "Cherry milk", icon = {25,23}, type = 0, pic = "milkCherry" },
	{ name = "Soy milk", icon = {27,23}, type = 1, pic = "milkSoy" },
	{ name = "Spiced milk", icon = {26,23}, type = 0, pic = "milkSpiced" },
	{ name = "Maple milk", icon = {28,23}, type = 0, pic = "milkMaple" },
	{ name = "Mint milk", icon = {29,23}, type = 0, pic = "milkMint" },
	{ name = "Licorice milk", icon = {30,23}, type = 0, pic = "milkLicorice" },
	{ name = "Rose milk", icon = {31,23}, type = 0, pic = "milkRose" },
	{ name = "Dragonfruit milk", icon = {21,24}, type = 0, pic = "milkDragonfruit" },
	{ name = "Melon milk", icon = {22,24}, type = 0, pic = "milkMelon" },
	{ name = "Blackcurrant milk", icon = {23,24}, type = 0, pic = "milkBlackcurrant" },
	{ name = "Peach milk", icon = {24,24}, type = 0, pic = "milkPeach" },
	{ name = "Hazelnut milk", icon = {25,24}, type = 0, pic = "milkHazelnut" },
}
-- Game.Milks: the ranked (type 0) milks; MILK_RANKS[1] is plain milk.
NS.MILK_RANKS = {}
for i, m in ipairs(NS.MILKS) do
	m.index = i - 1
	if m.type == 0 then
		m.rank = #NS.MILK_RANKS
		table.insert(NS.MILK_RANKS, m)
	end
end

-- Game.AllBGs; order >= 4.9 needs "Distinguished wallpaper assortment".
NS.BGS = {
	{ pic = "bgBlue", name = "Automatic", icon = {0,7} },
	{ pic = "bgBlue", name = "Blue", icon = {21,21} },
	{ pic = "bgRed", name = "Red", icon = {22,21} },
	{ pic = "bgWhite", name = "White", icon = {23,21} },
	{ pic = "bgBlack", name = "Black", icon = {24,21} },
	{ pic = "bgGold", name = "Gold", icon = {25,21} },
	{ pic = "grandmas1", name = "Grandmas", icon = {26,21} },
	{ pic = "grandmas2", name = "Displeased grandmas", icon = {27,21} },
	{ pic = "grandmas3", name = "Angered grandmas", icon = {28,21} },
	{ pic = "bgMoney", name = "Money", icon = {29,21} },
	{ pic = "bgPurple", name = "Purple", icon = {21,22}, order = 1.1 },
	{ pic = "bgPink", name = "Pink", icon = {24,22}, order = 2.1 },
	{ pic = "bgMint", name = "Mint", icon = {22,22}, order = 2.2 },
	{ pic = "bgSilver", name = "Silver", icon = {25,22}, order = 4.9 },
	{ pic = "bgBW", name = "Black & White", icon = {23,22}, order = 4.1 },
	{ pic = "bgSpectrum", name = "Spectrum", icon = {28,22}, order = 4.2 },
	{ pic = "bgCandy", name = "Candy", icon = {26,22} },
	{ pic = "bgYellowBlue", name = "Biscuit store", icon = {27,22} },
	{ pic = "bgChoco", name = "Chocolate", icon = {30,21} },
	{ pic = "bgChocoDark", name = "Dark Chocolate", icon = {31,21} },
	{ pic = "bgPaint", name = "Painter", icon = {24,34} },
	{ pic = "bgSnowy", name = "Snow", icon = {30,22} },
	{ pic = "bgSky", name = "Sky", icon = {29,22} },
	{ pic = "bgStars", name = "Night", icon = {31,22} },
	{ pic = "bgFoil", name = "Foil", icon = {25,34} },
}
for i, bg in ipairs(NS.BGS) do
	bg.index = i - 1
	bg.order = bg.order or (i - 1)
end

-- Game.foolObjects: what the buildings are called on Business day.
NS.FOOL_OBJECTS = {
	Unknown = { name = "Investment", desc = "You're not sure what this does, you just know it means profit.", icon = 0 },
	["Cursor"] = { name = "Rolling pin", desc = "Essential in flattening dough. The first step in cookie-making.", icon = 0 },
	["Grandma"] = { name = "Oven", desc = "A crucial element of baking cookies.", icon = 1 },
	["Farm"] = { name = "Kitchen", desc = "The more kitchens, the more cookies your employees can produce.", icon = 2 },
	["Mine"] = { name = "Secret recipe", desc = "These give you the edge you need to outsell those pesky competitors.", icon = 3 },
	["Factory"] = { name = "Factory", desc = "Mass production is the future of baking. Seize the day, and synergize!", icon = 4 },
	["Bank"] = { name = "Investor", desc = "Business folks with a nose for profit, ready to finance your venture as long as there's money to be made.", icon = 5 },
	["Temple"] = { name = "Like", desc = "Your social media page is going viral! Amassing likes is the key to a lasting online presence and juicy advertising deals.", icon = 9 },
	["Wizard tower"] = { name = "Meme", desc = "Cookie memes are all the rage! With just the right amount of social media astroturfing, your brand image will be all over the cyberspace.", icon = 6 },
	["Shipment"] = { name = "Supermarket", desc = "A gigantic cookie emporium - your very own retail chain.", icon = 7 },
	["Alchemy lab"] = { name = "Stock share", desc = "You're officially on the stock market, and everyone wants a piece!", icon = 8 },
	["Portal"] = { name = "TV show", desc = "Your cookies have their own sitcom! Hilarious baking hijinks set to the cheesiest laughtrack.", icon = 10 },
	["Time machine"] = { name = "Theme park", desc = "Cookie theme parks, full of mascots and roller-coasters. Build one, build a hundred!", icon = 11 },
	["Antimatter condenser"] = { name = "Cookiecoin", desc = "A virtual currency, already replacing regular money in some small countries.", icon = 12 },
	["Prism"] = { name = "Corporate country", desc = "You've made it to the top, and you can now buy entire nations to further your corporate greed. Godspeed.", icon = 13 },
	["Chancemaker"] = { name = "Privatized planet", desc = "Actually, you know what's cool? A whole planet dedicated to producing, advertising, selling, and consuming your cookies.", icon = 15 },
	["Fractal engine"] = { name = "Senate seat", desc = "Only through political dominion can you truly alter this world to create a brighter, more cookie-friendly future.", icon = 16 },
	["Javascript console"] = { name = "Doctrine", desc = "Taking many forms -religion, culture, philosophy- a doctrine may, when handled properly, cause a lasting impact on civilizations, reshaping minds and people and ensuring all future generations share a singular goal - the production, and acquisition, of more cookies.", icon = 17 },
	["Idleverse"] = { name = "Lateral expansions", desc = "Sometimes the best way to keep going up is sideways. Diversify your ventures through non-cookie investments.", icon = 18 },
	["Cortex baker"] = { name = "Think tank", desc = "There's only so many ways you can bring in more profit. Or is there? Hire the most brilliant experts in the known universe and let them scrounge up new ideas for you.", icon = 19 },
	["You"] = { name = "You", desc = "Your business is as great as it's gonna get. The only real way to improve it anymore is to improve yourself - and become the best Chief Executive Officer you can be.", icon = 20 },
}

-- Game.goldenCookieBuildingBuffs: building special buff and debuff names.
NS.BUILDING_BUFFS = {
	["Cursor"] = { "High-five", "Slap to the face" },
	["Grandma"] = { "Congregation", "Senility" },
	["Farm"] = { "Luxuriant harvest", "Locusts" },
	["Mine"] = { "Ore vein", "Cave-in" },
	["Factory"] = { "Oiled-up", "Jammed machinery" },
	["Bank"] = { "Juicy profits", "Recession" },
	["Temple"] = { "Fervent adoration", "Crisis of faith" },
	["Wizard tower"] = { "Manabloom", "Magivores" },
	["Shipment"] = { "Delicious lifeforms", "Black holes" },
	["Alchemy lab"] = { "Breakthrough", "Lab disaster" },
	["Portal"] = { "Righteous cataclysm", "Dimensional calamity" },
	["Time machine"] = { "Golden ages", "Time jam" },
	["Antimatter condenser"] = { "Extra cycles", "Predictable tragedy" },
	["Prism"] = { "Solar flare", "Eclipse" },
	["Chancemaker"] = { "Winning streak", "Dry spell" },
	["Fractal engine"] = { "Macrocosm", "Microcosm" },
	["Javascript console"] = { "Refactoring", "Antipattern" },
	["Idleverse"] = { "Cosmic nursery", "Big crunch" },
	["Cortex baker"] = { "Brainstorm", "Brain freeze" },
	["You"] = { "Deduplication", "Clone strike" },
}

NS.GOLDEN_UPGRADES = { "Get lucky", "Lucky day", "Serendipity", "Heavenly luck", "Lasting fortune", "Decisive fate", "Lucky digit", "Lucky number", "Lucky payout", "Golden goose egg" }

NS.DRAGON_DROPS = { "Dragon scale", "Dragon claw", "Dragon fang", "Dragon teddy bear" }

NS.REINDEER_NAMES = { "Dasher", "Dancer", "Prancer", "Vixen", "Comet", "Cupid", "Donner", "Blitzen", "Rudolph" }

NS.CHIMES = {
	{ name = "No sound", icon = {0,7} },
	{ name = "Chime", icon = {22,6} },
	{ name = "Fortune", icon = {27,6} },
	{ name = "Cymbal", icon = {9,10} },
	{ name = "Squeak", icon = {8,10} },
}

-- Grandma sprite per grandma-type upgrade (the row picks at random from
-- the owned ones; the seasonal ones join during Christmas and Easter).
NS.GRANDMA_PICS = {
	["Farmer grandmas"] = "farmerGrandma", ["Worker grandmas"] = "workerGrandma", ["Miner grandmas"] = "minerGrandma",
	["Cosmic grandmas"] = "cosmicGrandma", ["Transmuted grandmas"] = "transmutedGrandma", ["Altered grandmas"] = "alteredGrandma",
	["Grandmas' grandmas"] = "grandmasGrandma", ["Antigrandmas"] = "antiGrandma", ["Rainbow grandmas"] = "rainbowGrandma",
	["Banker grandmas"] = "bankGrandma", ["Priestess grandmas"] = "templeGrandma", ["Witch grandmas"] = "witchGrandma",
	["Lucky grandmas"] = "luckyGrandma", ["Metagrandmas"] = "metaGrandma", ["Script grannies"] = "scriptGrandma",
	["Alternate grandmas"] = "alternateGrandma", ["Brainy grandmas"] = "brainyGrandma", ["Clone grandmas"] = "cloneGrandma",
}

NS.LUMP_TYPES = { [0] = "normal", "bifurcated", "golden", "meaty", "caramelized" }

-- The 1-in-10,000 golden cookie that does nothing.
NS.BLAB = {
	"Cookie crumbliness x3 for 60 seconds!", "Chocolatiness x7 for 77 seconds!", "Dough elasticity halved for 66 seconds!",
	"Golden cookie shininess doubled for 3 seconds!", "World economy halved for 30 seconds!", "Grandma kisses 23% stingier for 45 seconds!",
	"Thanks for clicking!", "Fooled you! This one was just a test.", "Golden cookies clicked +1!",
	"Your click has been registered. Thank you for your cooperation.", "Thanks! That hit the spot!", "Thank you. A team has been dispatched.",
	"They know.", "Oops. This was just a chocolate cookie with shiny aluminium foil.", "Eschaton immanentized!", "Oh, that tickled!",
	"Again.", "You've made a grave mistake.", "Chocolate chips reshuffled!", "Randomized chance card outcome!", "Mouse acceleration +0.03%!",
	"Ascension bonuses x5,000 for 0.1 seconds!", "Gained 1 extra!", "Sorry, better luck next time!", "I felt that.", "Nice try, but no.",
	"Wait, sorry, I wasn't ready yet.", "Yippee!", "Bones removed.", "Organs added.", "Did you just click that?",
	"Huh? Oh, there was nothing there.", "You saw nothing.", "It seems you hallucinated that golden cookie.",
	"This golden cookie was a complete fabrication.", "In theory there's no wrong way to click a golden cookie, but you just did that, somehow.",
	"All cookies multiplied by 999! All cookies divided by 999!", "Why?",
}
