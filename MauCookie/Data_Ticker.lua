-- MauCookie: the news ticker lines, copied from the original's
-- Game.getNewTicker (main.js version 2.052).  Ticker.lua builds the list
-- of candidates each time; "%A" stands for a random animal, "%B" for the
-- bakery name, "%N" for a number (see the substitutions in Ticker.lua).

local _, NS = ...

local T = {}
NS.TICKER = T

T.ANIMALS = { "newts", "penguins", "scorpions", "axolotls", "puffins", "porpoises", "blowfish", "horses", "crayfish", "slugs", "humpback whales", "nurse sharks", "giant squids", "polar bears", "fruit bats", "frogs", "sea squirts", "velvet worms", "mole rats", "paramecia", "nematodes", "tardigrades", "giraffes", "monkfish", "wolfmen", "goblins", "hippies" }

T.GRANDMA = { "Moist cookies.", "We're nice grandmas.", "Indentured servitude.", "Come give grandma a kiss.", "Why don't you visit more often?", "Call me..." }
T.GRANDMA_THREATENING = { "Absolutely disgusting.", "You make me sick.", "You disgust me.", "We rise.", "It begins.", "It'll all be over soon.", "You could have stopped it." }
T.GRANDMA_ANGRY = { "It has betrayed us, the filthy little thing.", "It tried to get rid of us, the nasty little thing.", "It thought we would go away by selling us. How quaint.", "I can smell your rotten cookies." }
T.GRANDMA_RETURN = { "shrivel", "writhe", "throb", "gnaw", "We will rise again.", "A mere setback.", "We are not satiated.", "Too late." }

-- One random line per owned building kind.
T.BUILDINGS = {
	["Farm"] = {
		"News : cookie farms suspected of employing undeclared elderly workforce!",
		"News : cookie farms release harmful chocolate in our rivers, says scientist!",
		"News : genetically-modified chocolate controversy strikes cookie farmers!",
		"News : free-range farm cookies popular with today's hip youth, says specialist.",
		"News : farm cookies deemed unfit for vegans, says nutritionist.",
	},
	["Mine"] = {
		"News : is our planet getting lighter? Experts examine the effects of intensive chocolate mining.",
		"News : %N1000+2 miners trapped in collapsed chocolate mine!",
		"News : chocolate mines found to cause earthquakes and sinkholes!",
		"News : chocolate mine goes awry, floods village in chocolate!",
		"News : depths of chocolate mines found to house \"peculiar, chocolaty beings\"!",
	},
	["Factory"] = {
		"News : cookie factories linked to global warming!",
		"News : cookie factories involved in chocolate weather controversy!",
		"News : cookie factories on strike, robotic minions employed to replace workforce!",
		"News : cookie factories on strike - workers demand to stop being paid in cookies!",
		"News : factory-made cookies linked to obesity, says study.",
	},
	["Bank"] = {
		"News : cookie loans on the rise as people can no longer afford them with regular money.",
		"News : cookies slowly creeping up their way as a competitor to traditional currency!",
		"News : most bakeries now fitted with ATMs to allow for easy cookie withdrawals and deposits.",
		"News : cookie economy now strong enough to allow for massive vaults doubling as swimming pools!",
		"News : \"Tomorrow's wealthiest people will be calculated by their worth in cookies\", predict economists.",
	},
	["Temple"] = {
		"News : explorers bring back ancient artifact from abandoned temple; archeologists marvel at the centuries-old %{magic|carved|engraved|sculpted|royal|imperial|mummified|ritual|golden|silver|stone|cursed|plastic|bone|blood|holy|sacred|sacrificial|electronic|singing|tapdancing} %{spoon|fork|pizza|washing machine|calculator|hat|piano|napkin|skeleton|gown|dagger|sword|shield|skull|emerald|bathtub|mask|rollerskates|litterbox|bait box|cube|sphere|fungus}!",
		"News : recently-discovered chocolate temples now sparking new cookie-related cult; thousands pray to Baker in the sky!",
		"News : just how extensive is the cookie pantheon? Theologians speculate about possible %{god|goddess} of %{%A|kazoos|web design|web browsers|kittens|atheism|handbrakes|hats|aglets|elevator music|idle games|the letter \"P\"|memes|hamburgers|bad puns|kerning|stand-up comedy|failed burglary attempts|clickbait|one weird tricks}.",
		"News : theists of the world discover new cookie religion - \"Oh boy, guess we were wrong all along!\"",
		"News : cookie heaven allegedly \"sports elevator instead of stairway\"; cookie hell \"paved with flagstone, as good intentions make for poor building material\".",
	},
	["Wizard tower"] = {
		"News : all %{%A|public restrooms|clouds|politicians|moustaches|hats|shoes|pants|clowns|encyclopedias|websites|potted plants|lemons|household items|bodily fluids|cutlery|national landmarks|yogurt|rap music|underwear} turned into %{%A|public restrooms|clouds|politicians|moustaches|hats|shoes|pants|clowns|encyclopedias|websites|potted plants|lemons|household items|bodily fluids|cutlery|national landmarks|yogurt|rap music|underwear} in freak magic catastrophe!",
		"News : heavy dissent rages between the schools of %{water|fire|earth|air|lightning|acid|song|battle|peace|pencil|internet|space|time|brain|nature|techno|plant|bug|ice|poison|crab|kitten|dolphin|bird|punch|fart} magic and %{water|fire|earth|air|lightning|acid|song|battle|peace|pencil|internet|space|time|brain|nature|techno|plant|bug|ice|poison|crab|kitten|dolphin|bird|punch|fart} magic!",
		"News : get your new charms and curses at the yearly National Spellcrafting Fair! Exclusive prices on runes and spellbooks.",
		"News : cookie wizards deny involvement in shockingly ugly newborn - infant is \"honestly grody-looking, but natural\", say doctors.",
		"News : \"Any sufficiently crude magic is indistinguishable from technology\", claims renowned technowizard.",
	},
	["Shipment"] = {
		"News : new chocolate planet found, becomes target of cookie-trading spaceships!",
		"News : massive chocolate planet found with 99.8% certified pure dark chocolate core!",
		"News : space tourism booming as distant planets attract more bored millionaires!",
		"News : chocolate-based organisms found on distant planet!",
		"News : ancient baking artifacts found on distant planet; \"terrifying implications\", experts say.",
	},
	["Alchemy lab"] = {
		"News : national gold reserves dwindle as more and more of the precious mineral is turned to cookies!",
		"News : chocolate jewelry found fashionable, gold and diamonds \"just a fad\", says specialist.",
		"News : silver found to also be transmutable into white chocolate!",
		"News : defective alchemy lab shut down, found to convert cookies to useless gold.",
		"News : alchemy-made cookies shunned by purists!",
	},
	["Portal"] = {
		"News : nation worried as more and more unsettling creatures emerge from dimensional portals!",
		"News : dimensional portals involved in city-engulfing disaster!",
		"News : tourism to cookieverse popular with bored teenagers! Casualty rate as high as 73%!",
		"News : cookieverse portals suspected to cause fast aging and obsession with baking, says study.",
		"News : \"do not settle near portals,\" says specialist; \"your children will become strange and corrupted inside.\"",
	},
	["Time machine"] = {
		"News : time machines involved in history-rewriting scandal! Or are they?",
		"News : time machines used in unlawful time tourism!",
		"News : cookies brought back from the past \"unfit for human consumption\", says historian.",
		"News : various historical figures inexplicably replaced with talking lumps of dough!",
		"News : \"I have seen the future,\" says time machine operator, \"and I do not wish to go there again.\"",
	},
	["Antimatter condenser"] = {
		"News : whole town seemingly swallowed by antimatter-induced black hole; more reliable sources affirm town \"never really existed\"!",
		"News : \"explain to me again why we need particle accelerators to bake cookies?\" asks misguided local woman.",
		"News : first antimatter condenser successfully turned on, doesn't rip apart reality!",
		"News : researchers conclude that what the cookie industry needs, first and foremost, is \"more magnets\".",
		"News : \"unravelling the fabric of reality just makes these cookies so much tastier\", claims scientist.",
	},
	["Prism"] = {
		"News : new cookie-producing prisms linked to outbreak of rainbow-related viral videos.",
		"News : scientists warn against systematically turning light into matter - \"One day, we'll end up with all matter and no light!\"",
		"News : cookies now being baked at the literal speed of light thanks to new prismatic contraptions.",
		"News : \"Can't you sense the prism watching us?\", rambles insane local man. \"No idea what he's talking about\", shrugs cookie magnate/government official.",
		"News : world citizens advised \"not to worry\" about frequent atmospheric flashes.",
	},
	["Chancemaker"] = {
		"News : strange statistical anomalies continue as weather forecast proves accurate an unprecedented 3 days in a row!",
		"News : local casino ruined as all gamblers somehow hit a week-long winning streak! \"We might still be okay\", says owner before being hit by lightning 47 times.",
		"News : neighboring nation somehow elects president with sensible policies in freak accident of random chance!",
		"News : million-to-one event sees gritty movie reboot turning out better than the original! \"We have no idea how this happened\", say movie execs.",
		"News : all scratching tickets printed as winners, prompting national economy to crash and, against all odds, recover overnight.",
	},
	["Fractal engine"] = {
		"News : local man \"done with Cookie Clicker\", finds the constant self-references \"grating and on-the-nose\".",
		"News : local man sails around the world to find himself - right where he left it.",
		"News : local guru claims \"there's a little bit of ourselves in everyone\", under investigation for alleged cannibalism.",
		"News : news writer finds herself daydreaming about new career. Or at least a raise.",
		"News : polls find idea of cookies made of cookies \"acceptable\" - \"at least we finally know what's in them\", says interviewed citizen.",
	},
	["Javascript console"] = {
		"News : strange fad has parents giving their newborns names such as Emma.js or Liam.js. At least one Baby.js reported.",
		"News : coding is hip! More and more teenagers turn to technical fields like programming, ensuring a future robot apocalypse and the doom of all mankind.",
		"News : developers unsure what to call their new javascript libraries as all combinations of any 3 dictionary words have already been taken.",
		"News : nation holds breath as nested ifs about to hatch.",
		"News : clueless copywriter forgets to escape a quote, ends news line prematurely; last words reported to be \"Huh, why isn",
	},
	["Idleverse"] = {
		"News : is another you living out their dreams in an alternate universe? Probably, you lazy bum!",
		"News : public recoils at the notion of a cosmos made of infinite idle games. \"I kinda hoped there'd be more to it\", says distraught citizen.",
		"News : with an infinity of parallel universes, people turn to reassuring alternate dimensions, which only number \"in the high 50s\".",
		"News : \"I find solace in the knowledge that at least some of my alternate selves are probably doing fine out there\", says citizen's last remaining exemplar in the multiverse.",
		"News : comic book writers point to actual multiverse in defense of dubious plot points. \"See? I told you it wasn't 'hackneyed and contrived'!\"",
	},
	["Cortex baker"] = {
		"News : cortex baker wranglers kindly remind employees that cortex bakers are the bakery's material property and should not be endeared with nicknames.",
		"News : space-faring employees advised to ignore unusual thoughts and urges experienced within 2 parsecs of gigantic cortex bakers, say guidelines.",
		"News : astronomers warn of cortex baker trajectory drift, fear future head-on collisions resulting in costly concussions.",
		"News : runt cortex baker identified with an IQ of only quintuple digits: \"just a bit of a dummy\", say specialists.",
		"News : are you smarter than a cortex baker? New game show deemed \"unfair\" by contestants.",
	},
	["You"] = {
		"News : the person of the year is, this year again, %B! How unexpected!",
		"News : criminals caught sharing pirated copies of %B's genome may be exposed to fines and up to 17 billion years prison, reminds constable.",
		"News : could local restaurants be serving you bootleg %B clone meat? Our delicious investigation follows after tonight's news.",
		"News : beloved cookie magnate %B, erroneously reported as trampled to death by crazed fans, thankfully found to be escaped clone mistaken for original.",
		"News : \"Really, we're just looking for some basic societal acceptance and compassion\", mumbles incoherent genetic freak %B-Clone #59014.",
	},
}

T.SEASONS = {
	halloween = {
		"News : strange twisting creatures amass around cookie factories, nibble at assembly lines.",
		"News : ominous wrinkly monsters take massive bites out of cookie production; \"this can't be hygienic\", worries worker.",
		"News : pagan rituals on the rise as children around the world dress up in strange costumes and blackmail homeowners for candy.",
		"News : new-age terrorism strikes suburbs as houses find themselves covered in eggs and toilet paper.",
		"News : children around the world \"lost and confused\" as any and all Halloween treats have been replaced by cookies.",
	},
	christmas = {
		"News : bearded maniac spotted speeding on flying sleigh! Investigation pending.",
		"News : Santa Claus announces new brand of breakfast treats to compete with cookie-flavored cereals! \"They're ho-ho-horrible!\" says Santa.",
		"News : \"You mean he just gives stuff away for free?!\", concerned moms ask. \"Personally, I don't trust his beard.\"",
		"News : obese jolly lunatic still on the loose, warn officials. \"Keep your kids safe and board up your chimneys. We mean it.\"",
		"News : children shocked as they discover Santa Claus isn't just their dad in a costume after all! \"I'm reassessing my life right now\", confides Laura, aged 6.",
		"News : mysterious festive entity with quantum powers still wrecking havoc with army of reindeer, officials say.",
		"News : elves on strike at toy factory! \"We will not be accepting reindeer chow as payment anymore. And stop calling us elves!\"",
		"News : elves protest around the nation; wee little folks in silly little outfits spread mayhem, destruction; rabid reindeer running rampant through streets.",
		"News : scholars debate regarding the plural of reindeer(s) in the midst of elven world war.",
		"News : elves \"unrelated to gnomes despite small stature and merry disposition\", find scientists.",
		"News : elves sabotage radioactive frosting factory, turn hundreds blind in vicinity - \"Who in their right mind would do such a thing?\" laments outraged mayor.",
		"News : drama unfolds at North Pole as rumors crop up around Rudolph's red nose; \"I may have an addiction or two\", admits reindeer.",
	},
	valentines = {
		"News : organ-shaped confectioneries being traded in schools all over the world; gruesome practice undergoing investigation.",
		"News : heart-shaped candies overtaking sweets business, offering competition to cookie empire. \"It's the economy, cupid!\"",
		"News : love's in the air, according to weather specialists. Face masks now offered in every city to stunt airborne infection.",
		"News : marrying a cookie - deranged practice, or glimpse of the future?",
		"News : boyfriend dumped after offering his lover cookies for Valentine's Day, reports say. \"They were off-brand\", shrugs ex-girlfriend.",
	},
	easter = {
		"News : long-eared critters with fuzzy tails invade suburbs, spread terror and chocolate!",
		"News : eggs have begun to materialize in the most unexpected places; \"no place is safe\", warn experts.",
		"News : packs of rampaging rabbits cause billions in property damage; new strain of myxomatosis being developed.",
		"News : egg-laying rabbits \"not quite from this dimension\", warns biologist; advises against petting, feeding, or cooking the creatures.",
		"News : mysterious rabbits found to be egg-layers, but mammalian, hinting at possible platypus ancestry.",
	},
}

-- 5% of the time: one line per owned upgrade or achievement from this list.
T.OWNED = {
	{ achiev = "Base 10", line = "News : cookie manufacturer completely forgoes common sense, lets strange obsession with round numbers drive building decisions!" },
	{ achiev = "From scratch", line = "News : follow the tear-jerking, riches-to-rags story about a local cookie manufacturer who decided to give it all up!" },
	{ achiev = "A world filled with cookies", line = "News : known universe now jammed with cookies! No vacancies!" },
	{ achiev = "Last Chance to See", line = "News : incredibly rare albino wrinkler on the brink of extinction poached by cookie-crazed pastry magnate!" },
	{ upgrade = "Serendipity", line = "News : local cookie manufacturer becomes luckiest being alive!" },
	{ upgrade = "Season switcher", line = "News : seasons are all out of whack! \"We need to get some whack back into them seasons\", says local resident." },
	{ upgrade = "Kitten helpers", line = "News : faint meowing heard around local cookie facilities; suggests new ingredient being tested." },
	{ upgrade = "Kitten workers", line = "News : crowds of meowing kittens with little hard hats reported near local cookie facilities." },
	{ upgrade = "Kitten engineers", line = "News : surroundings of local cookie facilities now overrun with kittens in adorable little suits. Authorities advise to stay away from the premises." },
	{ upgrade = "Kitten overseers", line = "News : locals report troupe of bossy kittens meowing adorable orders at passersby." },
	{ upgrade = "Kitten managers", line = "News : local office cubicles invaded with armies of stern-looking kittens asking employees \"what's happening, meow\"." },
	{ upgrade = "Kitten accountants", line = "News : tiny felines show sudden and amazing proficiency with fuzzy mathematics and pawlinomials, baffling scientists and pet store owners." },
	{ upgrade = "Kitten specialists", line = "News : new kitten college opening next week, offers courses on cookie-making and catnip studies." },
	{ upgrade = "Kitten experts", line = "News : unemployment rates soaring as woefully adorable little cats nab jobs on all levels of expertise, says study." },
	{ upgrade = "Kitten consultants", line = "News : \"In the future, your job will most likely be done by a cat\", predicts suspiciously furry futurologist." },
	{ upgrade = "Kitten assistants to the regional manager", line = "News : strange kittens with peculiar opinions on martial arts spotted loitering on local beet farms!" },
	{ upgrade = "Kitten marketeers", line = "News : nonsensical kitten billboards crop up all over countryside, trying to sell people the cookies they already get for free!" },
	{ upgrade = "Kitten analysts", line = "News : are your spending habits sensible? For a hefty fee, these kitten analysts will tell you!" },
	{ upgrade = "Kitten executives", line = "News : kittens strutting around in hot little business suits shouting cut-throat orders at their assistants, possibly the cutest thing this reporter has ever seen!" },
	{ upgrade = "Kitten admins", line = "News : all systems nominal, claim kitten admins obviously in way over their heads." },
	{ upgrade = "Kitten strategists", line = "News : overpaid kittens scratching their fuzzy little heads trying to find new ways to get cookies in your shopping cart!" },
	{ upgrade = "Kitten angels", line = "News : \"Try to ignore any ghostly felines that may be purring inside your ears,\" warn scientists. \"They'll just lure you into making poor life choices.\"" },
	{ upgrade = "Kitten wages", line = "News : kittens break glass ceiling! Do they have any idea how expensive those are!" },
	{ achiev = "Jellicles", line = "News : local kittens involved in misguided musical production, leave audience perturbed and unnerved." },
}

T.SUGAR = {
	"News : major sugar-smuggling ring dismantled by authorities; %N30+3 tons of sugar lumps seized, %N48+2 suspects apprehended.",
	"News : authorities warn tourists not to buy bootleg sugar lumps from street peddlers - \"You think you're getting a sweet deal, but what you're being sold is really just ordinary cocaine\", says agent.",
	"News : pro-glucose movement protests against sugar-shaming. \"I've eaten nothing but sugar lumps for the past %N10+4 years and I'm feeling great!\", says woman with friable skin.",
	"News : experts in bitter disagreement over whether sugar consumption turns children sluggish or hyperactive.",
	"News : fishermen deplore upturn in fish tooth decay as sugar lumps-hauling cargo sinks into the ocean.",
	"News : rare black sugar lump that captivated millions in unprecedented auction revealed to be common toxic fungus.",
	"News : \"Back in my day, sugar lumps were these little cubes you'd put in your tea, not those fist-sized monstrosities people eat for lunch\", whines curmudgeon with failing memory.",
	"News : sugar lump-snacking fad sweeps the nation; dentists everywhere rejoice.",
}

T.OMENS = {
	"You have been chosen. They will come soon.",
	"They're coming soon. Maybe you should think twice about opening the door.",
	"The end is near. Make preparations.",
	"News : broccoli tops for moms, last for kids; dads indifferent.",
	"News : middle age a hoax, declares study; turns out to be bad posture after all.",
	"News : kitties want answers in possible Kitty Kibble shortage.",
}

-- Past ten thousand cookies: one of each of these groups.
T.GENERIC_A = {
	"News : cookies found to %{increase lifespan|sensibly increase intelligence|reverse aging|decrease hair loss|prevent arthritis|cure blindness} in %A!",
	"News : cookies found to make %A %{more docile|more handsome|nicer|less hungry|more pragmatic|tastier}!",
	"News : cookies tested on %A, found to have no ill effects.",
	"News : cookies unexpectedly popular among %A!",
	"News : unsightly lumps found on %A near cookie facility; \"they've pretty much always looked like that\", say biologists.",
	"News : new species of %A discovered in distant country; \"yup, tastes like cookies\", says biologist.",
	"News : cookies go well with %{%{roasted|toasted|boiled|sauteed|minced} %A|%{sushi|soup|carpaccio|steak|nuggets} made from %A}, says controversial chef.",
	"News : \"do your cookies contain %A?\", asks PSA warning against counterfeit cookies.",
	"News : doctors recommend twice-daily consumption of fresh cookies.",
	"News : doctors warn against chocolate chip-snorting teen fad.",
	"News : doctors advise against new cookie-free fad diet.",
	"News : doctors warn mothers about the dangers of \"home-made cookies\".",
}
T.CELEBRITY = {
	"I'm all about cookies", "I just can't stop eating cookies. I think I seriously need help", "I guess I have a cookie problem",
	"I'm not addicted to cookies. That's just speculation by fans with too much free time", "my upcoming album contains 3 songs about cookies",
	"I've had dreams about cookies 3 nights in a row now. I'm a bit worried honestly", "accusations of cookie abuse are only vile slander",
	"cookies really helped me when I was feeling low", "cookies are the secret behind my perfect skin", "cookies helped me stay sane while filming my upcoming movie",
	"cookies helped me stay thin and healthy", "I'll say one word, just one : cookies", "alright, I'll say it - I've never eaten a single cookie in my life",
}
T.GENERIC_B = {
	"News : scientist predicts imminent cookie-related \"end of the world\"; becomes joke among peers.",
	"News : man robs bank, buys cookies.",
	"News : scientists establish that the deal with airline food is, in fact, a critical lack of cookies.",
	"News : hundreds of tons of cookies dumped into starving country from airplanes; thousands dead, nation grateful.",
	"News : new study suggests cookies neither speed up nor slow down aging, but instead \"take you in a different direction\".",
	"News : overgrown cookies found in fishing nets, raise questions about hormone baking.",
	"News : \"all-you-can-eat\" cookie restaurant opens in big city; waiters trampled in minutes.",
	"News : man dies in cookie-eating contest; \"a less-than-impressive performance\", says judge.",
	"News : what makes cookies taste so right? \"Probably all the [*****] they put in them\", says anonymous tipper.",
	"News : man found allergic to cookies; \"what a weirdo\", says family.",
	"News : foreign politician involved in cookie-smuggling scandal.",
	"News : cookies now more popular than %{cough drops|broccoli|smoked herring|cheese|video games|stable jobs|relationships|time travel|cat videos|tango|fashion|television|nuclear warfare|whatever it is we ate before|politics|oxygen|lamps}, says study.",
	"News : obesity epidemic strikes nation; experts blame %{twerking|that darn rap music|video-games|lack of cookies|mysterious ghostly entities|aliens|parents|schools|comic-books|cookie-snorting fad}.",
	"News : cookie shortage strikes town, people forced to eat cupcakes; \"just not the same\", concedes mayor.",
	"News : \"you gotta admit, all this cookie stuff is a bit ominous\", says confused idiot.",
	"News : is there life on Mars? Various chocolate bar manufacturers currently under investigation for bacterial contaminants.",
	"News : \"so I guess that's a thing now\", scientist comments on cookie particles now present in virtually all steel manufactured since cookie production ramped up worldwide.",
	"News : trace amounts of cookie particles detected in most living creatures, some of which adapting them as part of new and exotic metabolic processes.",
}
T.GENERIC_C = {
	"News : movie cancelled from lack of actors; \"everybody's at home eating cookies\", laments director.",
	"News : comedian forced to cancel cookie routine due to unrelated indigestion.",
	"News : new cookie-based religion sweeps the nation.",
	"News : fossil records show cookie-based organisms prevalent during Cambrian explosion, scientists say.",
	"News : mysterious illegal cookies seized; \"tastes terrible\", says police.",
	"News : man found dead after ingesting cookie; investigators favor \"mafia snitch\" hypothesis.",
	"News : \"the universe pretty much loops on itself,\" suggests researcher; \"it's cookies all the way down.\"",
	"News : minor cookie-related incident turns whole town to ashes; neighboring cities asked to chip in for reconstruction.",
	"News : is our media controlled by the cookie industry? This could very well be the case, says crackpot conspiracy theorist.",
	"News : %{cookie-flavored popcorn pretty damn popular; \"we kinda expected that\", say scientists.|cookie-flavored cereals break all known cereal-related records.|cookies popular among all age groups, including fetuses, says study.|cookie-flavored popcorn sales exploded during screening of Grandmothers II : The Moistening.}",
	"News : all-cookie restaurant opening downtown. Dishes such as braised cookies, cookie thermidor, and for dessert : crepes.",
	"News : \"Ook\", says interviewed orangutan.",
	"News : cookies could be the key to %{eternal life|infinite riches|eternal youth|eternal beauty|curing baldness|world peace|solving world hunger|ending all wars world-wide|making contact with extraterrestrial life|mind-reading|better living|better eating|more interesting TV shows|faster-than-light travel|quantum baking|chocolaty goodness|gooder thoughtness}, say scientists.",
	"News : flavor text %{not particularly flavorful|kind of unsavory|\"rather bland\"|pretty spicy lately}, study finds.",
}
T.GENERIC_D = {
	"News : what do golden cookies taste like? Study reveals a flavor \"somewhere between spearmint and liquorice\".",
	"News : what do wrath cookies taste like? Study reveals a flavor \"somewhere between blood sausage and seawater\".",
	"News : %B-brand cookies \"%{much less soggy|much tastier|relatively less crappy|marginally less awful|less toxic|possibly more edible|more fashionable|slightly nicer|trendier|arguably healthier|objectively better choice|slightly less terrible|decidedly cookier|a tad cheaper} than competitors\", says consumer survey.",
	"News : \"%B\" set to be this year's most popular baby name.",
	"News : new popularity survey says %B's the word when it comes to cookies.",
	"News : major city being renamed %Bville after world-famous cookie manufacturer.",
	"News : %{street|school|nursing home|stadium|new fast food chain|new planet|new disease|flesh-eating bacteria|deadly virus|new species of %A|new law|baby|programming language} to be named after %B, the world-famous cookie manufacturer.",
	"News : don't miss tonight's biopic on %B's irresistible rise to success!",
	"News : don't miss tonight's interview of %B by %{Bloprah|Blavid Bletterman|Blimmy Blimmel|Blellen Blegeneres|Blimmy Blallon|Blonan Blo'Brien|Blay Bleno|Blon Blewart|Bleven Blolbert|Lord Toxikhron of dimension 7-B19|%B's own evil clone}!",
	"News : people all over the internet still scratching their heads over nonsensical reference : \"Okay, but why an egg?\"",
	"News : viral video \"Too Many Cookies\" could be \"a grim commentary on the impending crisis our world is about to face\", says famous economist.",
	"News : \"memes from last year somehow still relevant\", deplore experts.",
	"News : cookie emoji most popular among teenagers, far ahead of \"judgmental OK hand sign\" and \"shifty-looking dark moon\", says study.",
}
T.GENERIC_E = {
	"News : births of suspiciously bald babies on the rise; ancient alien cabal denies involvement.",
	"News : \"at this point, cookies permeate the economy\", says economist. \"If we start eating anything else, we're all dead.\"",
	"News : pun in headline infuriates town, causes riot. 21 wounded, 5 dead; mayor still missing.",
	"Nws : ky btwn W and R brokn, plas snd nw typwritr ASAP.",
	"Neeeeews : \"neeeew EEEEEE keeeeey working fineeeeeeeee\", reeeports gleeeeeeeeful journalist.",
	"News : cookies now illegal in some backwards country nobody cares about. Political tensions rising; war soon, hopefully.",
	"News : irate radio host rambles about pixelated icons. \"None of the cookies are aligned! Can't anyone else see it? I feel like I'm taking crazy pills!\"",
	"News : nation cheers as legislators finally outlaw %{cookie criticism|playing other games than Cookie Clicker|pineapple on pizza|lack of cheerfulness|mosquitoes|broccoli|the human spleen|bad weather|clickbait|dabbing|the internet|memes|millennials}!",
	"News : %{local|area} %{man|woman} goes on journey of introspection, finds cookies : \"I honestly don't know what I was expecting.\"",
	"News : %{man|woman} wakes up from coma, %{tries cookie for the first time, dies.|regrets it instantly.|wonders \"why everything is cookies now\".|babbles incoherently about some supposed \"non-cookie food\" we used to eat.|cites cookies as main motivator.|asks for cookies.}",
	"News : pet %A, dangerous fad or juicy new market?",
	"News : person typing these wouldn't mind someone else breaking the news to THEM, for a change.",
	"News : \"average person bakes %Y cookies a year\" factoid actually just statistical error; %B, who has produced %E cookies in their lifetime, is an outlier and should not have been counted.",
	"News : \"Cookies are still produced while the game is closed\", say experts on the nature of our reality. Up next: the terrifying implications behind this statement.",
	"News : 97-year-old baker still makes cookies the old-fashioned way!",
}

-- Lore by progress (round(log10(cookiesEarned / 10) + 1)); index = progress + 1.
T.LORE = {
	{ "You feel like making cookies. But nobody wants to eat your cookies." },
	{ "Your first batch goes to the trash. The neighborhood raccoon barely touches it." },
	{ "Your family agrees to try some of your cookies." },
	{ "Your cookies are popular in the neighborhood.", "People are starting to talk about your cookies." },
	{ "Your cookies are talked about for miles around.", "Your cookies are renowned in the whole town!" },
	{ "Your cookies bring all the boys to the yard.", "Your cookies now have their own website!" },
	{ "Your cookies are worth a lot of money.", "Your cookies sell very well in distant countries." },
	{ "People come from very far away to get a taste of your cookies.", "Kings and queens from all over the world are enjoying your cookies." },
	{ "There are now museums dedicated to your cookies.", "A national day has been created in honor of your cookies." },
	{ "Your cookies have been named a part of the world wonders.", "History books now include a whole chapter about your cookies." },
	{ "Your cookies have been placed under government surveillance.", "The whole planet is enjoying your cookies!" },
	{ "Strange creatures from neighboring planets wish to try your cookies.", "Elder gods from the whole cosmos have awoken to taste your cookies." },
	{ "Beings from other dimensions lapse into existence just to get a taste of your cookies.", "Your cookies have achieved sentience." },
	{ "The universe has now turned into cookie dough, to the molecular level.", "Your cookies are rewriting the fundamental laws of the universe." },
	{ "A news team was teleported to the future to see what's next for your cookies. The team came back, but they're now wrinkled and aged.", "it's time to stop playing" },
}

T.WRATH = {
	[1] = {
		"News : millions of old ladies reported missing!",
		"News : processions of old ladies sighted around cookie facilities!",
		"News : families around the continent report agitated, transfixed grandmothers!",
		"News : doctors swarmed by cases of old women with glassy eyes and a foamy mouth!",
		"News : nurses report \"strange scent of cookie dough\" around female elderly patients!",
	},
	[2] = {
		"News : town in disarray as strange old ladies break into homes to abduct infants and baking utensils!",
		"News : sightings of old ladies with glowing eyes terrify local population!",
		"News : retirement homes report \"female residents slowly congealing in their seats\"!",
		"News : whole continent undergoing mass exodus of old ladies!",
		"News : old women freeze in place in streets, ooze warm sugary syrup!",
	},
	[3] = {
		"News : large \"flesh highways\" scar continent, stretch between various cookie facilities!",
		"News : wrinkled \"flesh tendrils\" visible from space!",
		"News : remains of \"old ladies\" found frozen in the middle of growing fleshy structures!",
		"News : all hope lost as writhing mass of flesh and dough engulfs whole city!",
		"News : nightmare continues as wrinkled acres of flesh expand at alarming speeds!",
	},
}

-- Business day.
T.FOOLS_MOOD = { "Your office chair is really comfortable.", "Profit's in the air!", "Business meetings are such a joy!", "What a great view from your office!", "Smell that? That's capitalism, baby!", "You truly love answering emails.", "Working hard, or hardly working?", "Another day in paradise!", "Expensive lunch time!", "Another government bailout coming up! Splendid!", "These profits are doing wonderful things for your skin.", "You daydream for a moment about a world without taxes.", "You'll worry about environmental damage when you're dead!", "Yay, office supplies!", "Sweet, those new staplers just came in!", "Ohh, coffee break!" }
T.FOOLS_AGENDA_A = { "You've spent the whole day", "Another great day", "First order of business today:", "Why, you truly enjoy", "What next? That's right,", "You check what's next on the agenda. Oh boy," }
T.FOOLS_AGENDA_B = { "signing contracts", "filling out forms", "touching base with the team", "examining exciting new prospects", "playing with your desk toys", "getting new nameplates done", "attending seminars", "videoconferencing", "hiring dynamic young executives", "meeting new investors", "updating your rolodex", "pumping up those numbers", "punching in some numbers", "getting investigated for workers' rights violations", "reorganizing documents", "belittling underlings", "reviewing employee performance", "revising company policies", "downsizing", "pulling yourself up by your bootstraps", "adjusting your tie", "performing totally normal human activities", "recentering yourself in the scream room", "immanentizing the eschaton", "shredding some sensitive documents", "comparing business cards", "pondering the meaning of your existence", "listening to the roaring emptiness inside your soul", "playing minigolf in your office" }
T.FOOLS_WORDS = { "viral", "search engine optimization", "blags and wobsites", "social networks", "webinette", "staycation", "user experience", "crowdfunding", "carbon neutral", "big data", "machine learning", "disrupting", "influencers", "monoconsensual transactions", "sustainable", "freemium", "incentives", "grassroots", "web 3.0", "logistics", "leveraging", "branding", "proactive", "synergizing", "market research", "demographics", "pie charts", "blogular", "blogulacious", "blogastic", "authenticity", "plastics", "electronic mail", "cellular phones", "rap music", "bulbs", "goblinization", "straight-to-bakery", "microbakeries", "chocolativity", "flavorfulness", "tastyfication", "sugar offsets", "activated wheat", "reification", "immanentize the eschaton", "cookies, I guess" }
T.FOOLS_RARE = {
	"If you could get some more cookies baked, that'd be great.", "So. About those TPS reports.", "Hmm, you've got some video tapes to return.",
	"They'll pay. They'll all pay.", "You haven't even begun to peak.",
	"There is an idea of a %B. Some kind of abstraction. But there is no real you, only an entity. Something illusory.", "This was a terrible idea!",
}
T.FOOLS_BUILDINGS = {
	["Cursor"] = { "Your rolling pins are rolling and pinning!", "Production is steady!" },
	["Grandma"] = { "Your ovens are diligently baking more and more cookies.", "Your ovens burn a whole batch. Ah well! Still good." },
	["Farm"] = { "Scores of cookies come out of your kitchens.", "Today, new recruits are joining your kitchens!" },
	["Mine"] = { "Your secret recipes are kept safely inside a giant underground vault.", "Your chefs are working on new secret recipes!" },
	["Factory"] = { "Your factories are producing an unending stream of baked goods.", "Your factory workers decide to go on strike!", "It's safety inspection day in your factories." },
	["Bank"] = { "Your shareholders are watching your business with great interest.", "Your investors are expecting to get their money's worth.", "Money talks! Your shares are soaring in value." },
	["Temple"] = { "Your social media managers are engaging in friendly ribbing with other brands!", "Another viral cookie post! Your social media managers are killing it.", "Your social media posts are fine-tuned for maximal user engagement!" },
	["Wizard tower"] = { "Your cookie memes have been deemed \"epic\" and \"awesomesauce\" by a panel of experts!", "\"Cringe\" or \"based\"? Experts weigh in on your cookie memes.", "You've successfully covered up another scandal with an onslaught of mildly-entertaining memes!" },
	["Shipment"] = { "Your supermarkets are bustling with happy, hungry customers.", "Your supermarkets are full of cookie merch!" },
	["Alchemy lab"] = { "It's a new trading day at the stock exchange, and traders can't get enough of your shares!", "Your stock is doubling in value by the minute!" },
	["Portal"] = { "You just released a new TV show episode!", "Your cookie-themed TV show is being adapted into a new movie!" },
	["Time machine"] = { "Your theme parks are doing well - puddles of vomit and roller-coaster casualties are being swept under the rug!", "Visitors are stuffing themselves with cookies before riding your roller-coasters. You might want to hire more clean-up crews." },
	["Antimatter condenser"] = { "Cookiecoin is officially the most mined digital currency in the history of mankind!", "Cookiecoin piracy is rampant!" },
	["Prism"] = { "Your corporate nations just gained a new parliament!", "You've just annexed a new nation!", "A new nation joins the grand cookie conglomerate!" },
	["Chancemaker"] = { "Your intergalactic federation of cookie-sponsored planets reports record-breaking profits!", "Billions of unwashed aliens are pleased to join your workforce as you annex their planet!", "New toll opened on interstellar highway, funnelling more profits into the cookie economy!" },
	["Fractal engine"] = { "Your cookie-based political party is doing fantastic in the polls!", "New pro-cookie law passes without a hitch thanks to your firm grasp of the political ecosystem!", "Your appointed senators are overturning cookie bans left and right!" },
	["Javascript console"] = { "Cookies are now one of the defining aspects of mankind! Congratulations!", "Time travelers report that this era will later come to be known, thanks to you, as the cookie millennium!", "Cookies now deeply rooted in human culture, likely puzzling future historians!" },
	["Idleverse"] = { "Public aghast as all remaining aspects of their lives overtaken by universal cookie industry!", "Every single product currently sold in the observable universe can be traced back to your company! And that's a good thing.", "Antitrust laws let out a helpless whimper before being engulfed by your sprawling empire!" },
	["Cortex baker"] = { "Bold new law proposal would grant default ownership of every new idea by anyone anywhere to %B's bakery!", "Bakery think tanks accidentally reinvent cookies for the 57th time this week!", "Bakery think tanks invent entire new form of human communication to advertise and boost cookie sales!" },
	["You"] = { "%B releases new self-help book: \"How I Made My %E Cookies And How You Can Too\"!", "Don't miss our interview tonight with the stupefying %B, who discusses where to go next once you're at the top!", "Fame, beauty, biscuits; %B has it all - but is it enough?" },
}
T.FOOLS_LORE = {
	"Such a grand day to begin a new business.", "You're baking up a storm!", "You are confident that one day, your cookie company will be the greatest on the market!",
	"Business is picking up!", "You're making sales left and right!", "Everyone wants to buy your cookies!", "You are now spending most of your day signing contracts!",
	"You've been elected \"business tycoon of the year\"!", "Your cookies are a worldwide sensation! Well done, old chap!",
	"Your brand has made its way into popular culture. Children recite your slogans and adults reminisce them fondly!",
	"A business day like any other. It's good to be at the top!", "You look back on your career. It's been a fascinating journey, building your baking empire from the ground up.",
}
