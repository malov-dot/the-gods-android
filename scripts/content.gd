extends RefCounted

const ERAS = [
	{"name":"Stone", "threshold":100.0, "color":"c8bc91", "description":"Foragers depend on local soil, forests, and clean water.", "food":1.0, "medicine":0.0, "trade":12.0, "military":1.0},
	{"name":"Tribal", "threshold":140.0, "color":"b8c68c", "description":"Farming supports permanent villages and new settlements.", "food":1.12, "medicine":0.02, "trade":15.0, "military":1.1},
	{"name":"Bronze", "threshold":190.0, "color":"d3a173", "description":"Granaries preserve food; metal tools raise productivity.", "food":1.26, "medicine":0.04, "trade":18.0, "military":1.3},
	{"name":"Iron", "threshold":250.0, "color":"a7b4bd", "description":"Iron weapons and workshops strengthen armies and trade.", "food":1.4, "medicine":0.06, "trade":21.0, "military":1.65},
	{"name":"Classical", "threshold":320.0, "color":"d4ccac", "description":"Aqueducts improve health; academies accelerate discovery.", "food":1.56, "medicine":0.12, "trade":24.0, "military":1.9},
	{"name":"Medieval", "threshold":410.0, "color":"b5a2c9", "description":"Irrigation supports cities; castles discourage conquest.", "food":1.72, "medicine":0.15, "trade":27.0, "military":2.2},
	{"name":"Renaissance", "threshold":520.0, "color":"d6b981", "description":"Printing spreads knowledge and religious disagreement.", "food":1.88, "medicine":0.19, "trade":31.0, "military":2.5},
	{"name":"Exploration", "threshold":650.0, "color":"79bdd0", "description":"Navigation permits sea trade and distant migration.", "food":2.03, "medicine":0.23, "trade":38.0, "military":2.9},
	{"name":"Industrial", "threshold":800.0, "color":"adaca7", "description":"Factories raise output and weapons production, but pollute soil.", "food":2.3, "medicine":0.28, "trade":44.0, "military":3.7},
	{"name":"Modern", "threshold":960.0, "color":"8eaec8", "description":"Hospitals reduce plague mortality; mass media spreads belief.", "food":2.6, "medicine":0.42, "trade":50.0, "military":4.4},
	{"name":"Atomic", "threshold":1120.0, "color":"c5cf75", "description":"Reactors fuel prosperity; desperate wars risk nuclear fallout.", "food":2.9, "medicine":0.5, "trade":56.0, "military":5.2},
	{"name":"Information", "threshold":1300.0, "color":"6fcac2", "description":"Networks spread research rapidly and challenge inherited faith.", "food":3.2, "medicine":0.57, "trade":64.0, "military":5.7},
	{"name":"AI", "threshold":1500.0, "color":"a995e6", "description":"Automation increases research and food; clean technology restores soil.", "food":3.65, "medicine":0.65, "trade":76.0, "military":6.2},
	{"name":"Space", "threshold":2000.0, "color":"90dbe8", "description":"Orbital habitats shelter people and deliver food and research to Earth.", "food":4.1, "medicine":0.72, "trade":90.0, "military":6.8}
]

const DOCTRINES = {
	"god":["Compassion", "Stewardship", "Knowledge", "Order", "Free Will"],
	"devil":["Ambition", "Temptation", "Chaos", "Forbidden Knowledge", "Dominion"]
}

const SCENARIOS = {
	"genesis":{"name":"Genesis", "description":"Young villages await the first signs of a higher power."},
	"fractured":{"name":"Fractured Faith", "description":"Rival kingdoms begin with strong, opposing religions."},
	"dying":{"name":"A Dying World", "description":"Drought, illness, and depleted stores test your intervention."},
	"enlightenment":{"name":"Enlightenment", "description":"Renaissance nations weigh reason against the supernatural."}
}

const NATION_NAMES = ["Ardan", "Veloria", "Solmere", "Nareth", "Thalassa", "Eldwyn", "Istria", "Morrow", "Calder", "Vesper"]
const NATION_COLORS = ["dcad65", "64b6c8", "a68ad4", "c96b79", "80b17b", "d29b7e", "7f9bd3", "c6be77", "b985b2", "6cbbb0"]
const PLACE_START = ["Ash", "River", "Dawn", "Elder", "Moon", "Stone", "Willow", "Bright", "Oak", "Frost", "Star", "Grey", "Sun", "Green", "Mist"]
const PLACE_END = ["haven", "ford", "mere", "fall", "wick", "field", "watch", "crest", "vale", "bridge", "hollow", "reach"]
const PERSON_NAMES = ["Elian", "Mira", "Darion", "Sera", "Kael", "Amara", "Ivo", "Liora", "Oren", "Nessa", "Rhea", "Tarin", "Soren", "Vela", "Ansel", "Yara", "Corin", "Nim"]
const TRAITS = ["generous", "ambitious", "cautious", "curious", "zealous", "merciful", "aggressive", "skeptical"]
const ERA_BUILDINGS = ["hearth", "farm", "granary", "forge", "aqueduct", "castle", "printing house", "harbor", "factory", "hospital", "reactor", "network", "automaton foundry", "spaceport"]

const ACHIEVEMENTS = {
	"first_city":"A settlement reaches 300 inhabitants.",
	"ten_towns":"Ten settlements coexist in your world.",
	"renaissance":"A civilization discovers printing.",
	"spacefarers":"Humanity establishes its first orbital habitat.",
	"centennial":"Your world remembers a hundred years.",
	"millennium":"Your world endures for a thousand years.",
	"schism":"A religion splits into competing traditions.",
	"peacekeeper":"A war ends through exhaustion or reconciliation."
}
