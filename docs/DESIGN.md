# Hands of God: Master Design Document

Oct 10, 2026 · @Sam

Hands of God is a 3D god game where your only verb is lifting people and setting them down. Across four eras, a tribe of two grows into a civilisation that builds a rocket and leaves, saying goodbye to you as it goes. This document is the source of truth for the full game. Everything not marked CORE is up for your ruling.

## How to read and rule on this doc

Every feature carries one tag:

- **\[CORE\]**: the bones. Removing it changes what the game is. Rule these out only if you disagree with the premise.
- **\[PROPOSED\]**: my recommendation. It fits the bones but you could cut it or swap it.
- **\[STRETCH\]**: worth doing if time allows after the full game is playable. Never blocks a milestone.

The last section, Rulings needed, collects every open decision in one table with a dropdown per row (In, Out, Later, Change). Pick one per row, or comment on any line anywhere in the doc. Anything you leave Undecided, I build as written.

All numbers (timings, costs, counts) are first-pass targets for tuning in playtests, not promises. Your Era 1 playtest notes are folded in throughout: start with two people, slower eras, grip that matters, and real art and music.

## 1. Vision and pillars

**The fantasy \[CORE\]:** you are a vast, gentle hand above a small valley. Two frightened people live there. You can't speak and you can't build; you can only lift them and set them down where work needs doing. They do the rest. Over generations they learn to trust you, then love you, and finally outgrow you. The last thing you ever place is their great-great-grandchild, into a rocket.

**Elevator pitch:** Kingdom for Keflings controls, Spore's arc from tribe to spaceflight, and a relationship with your people that ends in a goodbye. About 4 hours to the launch, then free play.

**Comparable games and what we take from each:**

| Game | What we take | What we leave |
| --- | --- | --- |
| A Kingdom for Keflings | Pick-up-and-place as the whole interface; watching workers is half the fun | Anonymous workers, no story |
| Spore | The civilisation arc and visible growth | Five separate genres |
| Black & White | A society that reacts to its god | Morality meters, a creature to train |
| Pikmin | A crowd you delegate to; group jobs that need N workers | Combat focus |
| Banished / Settlers | Production chains, families, generations | Menu-driven building and zoning |
| Journey | A wordless, earned emotional ending | (nothing to leave) |

### Five pillars \[CORE\]

1. **One verb.** Lift and place is the only input that changes the world. Every power is a new thing you can lift, or a new way to place. No build menus, no zoning, no unit panels.
2. **They know you.** Every villager has a name, a family and an opinion of the hand. They react when you hover, ask you for things, thank you, fear you, and remember what you did.
3. **Every power opens the world.** No power only changes a number. Each one opens a region, a new kind of job, or a new gesture.
4. **Growth you can see.** Progress shows on the people (clothes, tools, posture), on the land (huts to towers) and in your relationship (cave paintings of the hand become a mission patch). No stats screen is needed to know you're winning.
5. **A goodbye that's earned.** The ending only works if you remember the beginning, so lineage, memory and the hand symbol run through the whole game.

### What this game is not

- Not an RTS: no armies, no combat micro. Threats are hazards to shelter people from.
- Not a city builder with menus: buildings appear as plots the people want; you staff them.
- Not an incremental: no prestige resets, no exponential numbers.
- Not punishing: there is no game over. Setbacks cost people and time, never the save file.

### Audience and platform

- **Platform \[CORE\]:** Windows PC first (mouse and keyboard). Built in Godot 4.6, so a Mac and Linux export is nearly free \[PROPOSED\]. Controller and Steam Deck \[STRETCH\].
- **Audience:** cosy-strategy and god-game players who enjoy watching a place come alive. Calm by default, with tense nights and disasters for rhythm.
- **Session shape:** play in 20 to 60 minute sittings. Autosave everywhere, pause and speed controls (1x, 2x, 3x) always available.

## 2. The hand

The hand is the player character, the cursor and the only tool. It must feel heavy, warm and alive: it casts a shadow, its fingers curl as it nears something it can lift, it trembles under heavy loads and glows when people pray.

### Controls (mouse and keyboard) \[CORE\]

| Input | Action |
| --- | --- |
| Left click a person or object | Lift it |
| Left click a job, plot or building while holding | Set down there and start that job |
| Left hold and drag on the ground | **Scoop**: sweep a circle and lift everyone inside, up to your grip (needs Grip II) |
| Shift + left click | Add one more person to the hand without setting down |
| Right click | Set down here with no job |
| Double click a job | **Fill**: from Era 3, the hand gathers the nearest idle people and places up to your grip at once \[PROPOSED\] |
| Hold E with the hand over a person, field or fire | **Hold over**: the gesture for Warmth, Rain, Blessing, Shade (once unlocked) |
| Flick (fast drag then release while holding a small object) | Toss it a short way: shoo a wolf, throw a seed bag across the river \[PROPOSED\] |
| WASD or screen edges / middle drag | Pan |
| Q / E, mouse wheel | Rotate, zoom |
| Space / 1, 2, 3 | Pause / game speed |
| Tab | Show all labels; F1 opens the Village Book |

All keys remappable. Controller support is \[STRETCH\] (left stick moves the hand, A lifts, triggers scoop).

### Grip and weight \[CORE\]

Grip answers your playtest note that lifting more than one person had no point. Two numbers govern the hand:

- **Grip** = how many people at once (1, 3, 5, 10, 20 across the game; the hand starts at 1).
- **Strength** = the heaviest object you can lift. The hand starts at Strength 2 (a person, or the storm-night branch). A person weighs 1, a fallen log 4, a boulder or a bear 10, a cart 15, a house 40, a rocket stage 100. Strength I lifts 4, Strength II 10, Lift Buildings 40, Strength III 100.

Grip matters because many jobs need a group **at the same moment** (section 4): a heavy log needs 3 carriers, a hunt needs 4, a raft needs a crew of 5, a barn raising needs 8. People waiting at an unfilled group job wander off after about 20 seconds, so filling one by one is a race; enough grip turns it into one easy motion. Grip is how you start group jobs, and scoop is how you move a crowd. Each grip upgrade comes with a group job that needs it and a short in-game hint showing the scoop gesture.

### Hand feedback \[CORE\]

- A shadow and a target ring show exactly where the drop lands. A ghost preview shows which slot each held person takes.
- Hover a job while holding people: its label shows slots free, what it needs and how long the group will take.
- People in the hand dangle and kick their feet; children giggle, elders grumble, frightened people cover their eyes.
- Sound: a soft whoosh on lift, a thump on landing, a chime when a job starts. Pitch rises with each person added to the hand.

### What the hand cannot do \[CORE\]

It cannot build, harvest, fight or make anything. It cannot kill or harm people: a dropped person lands safely, always. These limits are what keep the people's work their own.

## 3. Villagers

The game starts with **two people** \[CORE\] and peaks around **150 to 200** by the launch. Population is itself a reward: every birth, newcomer and wedding is a small celebration.

### Life cycle \[CORE\]

| Stage | Game time | Can do | Notes |
| --- | --- | --- | --- |
| Baby | 0 to 6 min | Nothing | Carried by a parent; you can lift the cradle |
| Child | 6 to 15 min | Light jobs from Era 2 (berries, feeding animals, school) | Follows a parent, plays near home, waves at the hand most |
| Adult | 15 to 50 min | Every job | Pairs up, has children |
| Elder | 50 to 65 min | Slow work; **teaches** | An elder beside an apprentice doubles their skill gain |
| Death | \~65 min |  | A small funeral at the shrine; their name is carved on the memorial stones |

A new generation comes of age about every 20 to 30 minutes of play, so the launch crew are eight to ten generations after the first two people, and each era opens by naming its new generation. Times are scaled game time and tune with pacing.

### Population growth \[CORE\]

- **Births** happen when a bonded pair has a home with room, the village has had enough food for two days running, and the mood is content or better. You see a heart over the hut, then a cradle.
- **Newcomers** arrive with new regions (the four wanderers in the western meadow, a fishing family on the coast, traders who decide to stay).
- **Bonds** form between adults who work side by side. Placing two people on the same job is how you play matchmaker, and the hand can be credited at the wedding \[PROPOSED\].

### Needs \[CORE\]

Four needs, shown as small icons on the hover card, never as bars to babysit:

1. **Food:** eaten at dawn and dusk. Variety (berries, fish, bread, meat) raises mood from Era 2.
2. **Water:** carried from the river in Eras 1 and 2; wells and an aqueduct remove the chore later.
3. **Shelter and warmth:** a bed at night, heat in winter.
4. **Joy** (from Era 2): festivals, music at the fire, a market, a garden, time with family.

Unmet needs lower mood. Mood sets work speed (70% to 125%), birth rate and how much faith people give.

### Skills and traits

- **Skills \[CORE\]:** eight job families (Gathering, Woodcraft, Building, Farming, Crafting, Metalwork, Scholarship, Engineering), each rated 1 to 5 stars. People learn by doing and from elders. Five-star specialists get a title (Master Mason Teo) and a visible tool or outfit.
- **Traits \[PROPOSED\]:** each person has one or two of: Strong (carries more), Quick, Curious (learns fast), Devout (prays more, loves the hand), Timid (scared of the hand and the dark), Brave (fights fires and wolves), Sociable (bonds fast), Stubborn (ignores requests to move). Traits are inherited with a chance to mutate, so families develop character over generations.

### Names, faces and lineage \[CORE\]

- Every person has a generated name drawn from an era-appropriate name list, a face (skin, hair, eyes, build) and parents. Children resemble parents.
- The **Village Book** (F1) holds a family tree, a portrait of everyone alive, the memorial list, and a list of things the people remember you doing.
- The game tracks the **first two** as the root of the tree. The rocket crew are always chosen from their descendants, and the ending names the line from them to the crew.

**Naming \[CORE, ruled In\].** On the storm night the player can name the first two people (or keep the generated names). Later, a random event has a couple pray at the shrine "for the hand to name our baby": a name box appears, and the child carries that name in the Book with a small hand mark beside it.

### The autonomy dial \[CORE\]

The people get more self-directed each era, so placement stays meaningful instead of turning into hundreds of clicks:

| Era | What people do on their own | What still needs the hand |
| --- | --- | --- |
| 1 Tribe | Nothing. They keep doing the job you gave them, and run to shelter at night. | Every placement |
| 2 Village | Return to yesterday's job each morning; children copy a parent's job | New jobs, group jobs, disasters |
| 3 Town | **Foremen**: placing a skilled person on a workshop makes them recruit idle people to fill it | Foremen, crews, big projects |
| 4 Launch | **Guilds** staff whole chains; you set priorities by placing a person on a guild hall | Specialists, crews, giant lifts |

The hand never becomes useless: what you place gets rarer and more important (a master engineer, a launch crew, a rocket stage).

## 4. Jobs and production chains

Jobs get more complex every era in three ways \[CORE\]: from single jobs to **chains** (every link needs staffing or the chain stalls), from solo jobs to **group jobs** (N people must be present at once), and from untimed to **timed** jobs (harvest before frost, launch inside a weather window).

### Job types

| Type | How it works | Example |
| --- | --- | --- |
| Gather | Work a node, carry the result to a store, repeat | Berries, water, firewood |
| Craft | Take inputs from a store, work at a station, store the output | Mill grain into flour |
| Build | Fetch materials to a plot, then build with the people present | Hut, bridge, observatory |
| Group | Starts only when all N slots are filled at once; people who wait too long wander off | Haul a log (3), hunt (4), barn raising (8) |
| Tend | A slow loop with timed steps | Plant, water, weed, harvest a field |
| Haul | Move goods between stores; cuts walking time for chains | Cart driver (Era 3) |
| Lead | A foreman or guild master who staffs other jobs | Workshop foreman (Era 3) |
| Devotion | Pray, make offerings, play music; makes faith | Shrine keeper, choir |

### Era 1: Tribe (about 45 minutes)

| Job | Inputs | Output | Crew | Notes |
| --- | --- | --- | --- | --- |
| Gather berries | Bush | Berries | 1 to 2 | Bushes regrow; winter stops them |
| Fetch water | River | Water | 1 to 3 |  |
| Collect sticks | Undergrowth | Wood | 1 to 2 | Before people can fell trees |
| Fell a tree | Tree, stone axe | Logs | 1 to 2 | Needs the stone-axe discovery |
| **Haul a log** | Fallen log | 4 wood | **3** | First group job; teaches Grip II |
| Knap stone | Stone outcrop | Stone, then tools | 1 | Stone tools add +25% gather speed |
| Tend the fire | Wood | Light and warmth | 1 | The fire dies without wood at night |
| **Hunt** | Deer herd | Meat, hide | **4** | Group job; the hide makes winter clothes |
| Fish by hand | Shallows | Fish | 1 to 2 | Unlocked by the Warmth power (cold water) |
| Build | Wood, stone | Hut, drying rack, shrine, Stone Circle | 2 to 4 | Plots appear when people want them |

### Era 2: Village (about 60 minutes)

New chains: **farming** (clear field, sow, water, weed, harvest; seasons matter), **bread** (grain to the mill to flour, then the bakery to bread), **pottery** (clay pit to kiln to jars; jars raise store capacity), **copper and bronze** (ore, plus charcoal from a clamp, to the smelter, then the smith; bronze tools add +50% speed), **herding** (sheep for wool, then a loom for cloth), **boats** (a group of 5 builds a raft, fishing boats later). Group jobs: barn raising (8), bridge building (6), raft launch (5).

### Era 3: Town (about 70 minutes)

New chains: **masonry** (quarry blocks with the hand's Strength II, then a mason), **iron and steel** (bloomery to forge), **carts and roads** (haulers carry 10 and roads double their speed), **market** (caravans arrive to trade surplus for goods you can't make), **school** (children who attend gain skills faster and unlock Scholarship), **aqueduct** (removes the water chore, a giant group build), **observatory** (astronomers turn night watching into Research, the Era 4 currency). Foremen arrive here.

### Era 4: Launch (about 60 minutes)

New chains: **coal** (mine to powerhouse for electricity), **steel** (foundry), **rail** (lay track as a group job, trains run on their own), **chemistry** (refinery to rocket fuel), **assembly** (factory builds rocket parts), **crew training** (best Engineering, Scholarship and devout people). The final project is the rocket itself (section 9): every chain must be running at once, inside a weather window. Guilds arrive here.

## 5. Eras and progression

Four eras take about 4 hours to the launch \[CORE\]. Each era is gated by **three milestone projects**, not a checklist: the people dream them up (section 7) and the third one completes the era. Your note that Era 1 went too fast is answered by fewer, bigger goals, a smaller starting tribe, and seasons.

### Era by era

|  | Era 1 Tribe | Era 2 Village | Era 3 Town | Era 4 Launch |
| --- | --- | --- | --- | --- |
| Target length | 45 min | 60 min | 70 min | 60 min, then the goodbye |
| People at the end | 12 to 20 | 40 to 60 | 90 to 130 | 150 to 200 |
| Milestone 1 | First hut and the fire circle | Granary (survive a winter on stores) | School | Powerhouse (the valley lights up at night) |
| Milestone 2 | Shrine to the hand | Bridge over the great river | Aqueduct | Launch tower |
| Milestone 3 (era gate) | Stone Circle | Temple of the Hand | Observatory | The rocket |
| New threats | Wolves, cold nights, first winter | Flood, drought, bears, blight | Town fire, sickness, storms | Accidents, smog, launch scrub |
| The look | Hide clothes, thatch, firelight | Wool and linen, timber and daub, fields | Stone, tiles, lanterns, carts | Brick, steel, rail, electric light |

&#91;embedded content: the four eras · gates and the land each power opens\]

Read left to right: each era's powers open new regions (section 10), and the gate project closes the era. Only the rocket is highlighted because it is the one gate that ends the story.

### The era transition \[CORE\]

When the gate project completes, the game holds a short moment: the camera pulls back, the season turns, and a time-lapse shows the village growing into its new form over a few seconds. Older buildings are upgraded in place (a hut becomes a cottage), so the map you built is the map you keep. A new generation is introduced by name.

### Seasons \[PROPOSED\]

A year is four seasons of about 4 minutes each (one in-game day lasts 60 to 90 seconds plus night). Spring sows, summer grows, autumn harvests and stores, winter is cold, short and dangerous. Seasons pace the game, give timed jobs a reason to exist, and make the first winter Era 1's real test.

### Pacing rules

- A new thing to do (job, power, region or building) every 3 to 5 minutes.
- A milestone every 15 to 25 minutes.
- Never more than one major threat at once in Eras 1 and 2.
- A quiet stretch (no threat, no deadline) after every milestone, for watching and tidying.

## 6. Powers of the hand

Sixteen powers over four eras, and every one opens a region, a job or a gesture \[CORE\]. Powers are bought with **faith** at the shrine (and later the temple). Each power comes with a short lesson the first time it's used.

### The power list

| Era | Power | What it lets you do | What it opens |
| --- | --- | --- | --- |
| 1 | Grip II | Lift 3 people; unlocks the scoop gesture. Granted free as the first gift (section 11.4) | Log hauling and the hunt (group jobs) |
| 1 | Strength I | Lift weight 4 (fallen logs) | The western meadow: wanderers, stone, rich bushes |
| 1 | Warmth | Hold over people or a fire to warm them | Survive the first winter; hand-fishing in cold water |
| 1 | Blessing | People you set down work 2x for 30 s | The first festival (a blessed crowd dances at the fire for +20 faith) and the great elk hunt, which only blessed hunters can win |
| 2 | Reach | Place people across the great river | The east bank (clay, ore) before the bridge exists |
| 2 | Rain | Hold over fields to water them | The dry southern plains become farmland |
| 2 | Grip III | Lift 5; wider scoop | Barn raising and the raft crew |
| 2 | Strength II | Lift weight 10 (boulders) | The hill quarry behind the rockfall |
| 3 | Lift Buildings | Pick up a whole house and move it | Rearranging your layout and rebuilding above the flood line. Always optional: no goal ever forces you to move a building |
| 3 | Calm Waters | Hold over the sea to still it | The coast and the islands by boat |
| 3 | Grip IV | Lift 10 | Aqueduct crews; moving whole families |
| 3 | Guiding Light | Hold over the night sky to clear it | Astronomy at the observatory; northern lights event |
| 4 | Strength III | Lift weight 100 (rocket stages, rail cars) | Assembling the rocket; laying rail across the gorge |
| 4 | Part the Clouds | Hold over the sky to open a weather window | The launch itself |
| 4 | Grip V | Lift 20 | The stacking crew: 20 engineers carried to the gantry at once for the final rocket stage; evacuating a burning district |
| 4 | Steady Hand | Fine placement at slow speed | Docking stages, threading the crew gantry |

The old prototype's Strength opening the western pass stays as the template for this whole list.

### Faith \[CORE\]

Faith is the only currency the hand spends. It is earned from the relationship, so caring for the people is how the hand grows:

| Source | Faith |
| --- | --- |
| A job completed by someone you placed | +0.2 |
| A wish granted (section 7) | +4 to +10 |
| A gift picked up | +3, more from friends of the hand |
| Prayer at the shrine, per worshipper | +0.1 a second |
| A milestone built | +15 |
| A night or disaster survived with no losses | +5 |
| A festival (Era 2 and later) | +20 |

Power costs climb from 10 (Strength I, the first bought power) to about 400 (Part the Clouds). Faith is never lost or drained: a neglected village simply earns less of it. Ignored, frightened or hungry people pray less, and a lost person's family prays less for a while.

**Faith budget per era \[PROPOSED\].** These are targets the test bot checks on every build, and they are what keeps an era from being rushed: you cannot afford the next region's power until the village has grown into it.

| Era | Faith earned (target) | Powers bought | Their total cost |
| --- | --- | --- | --- |
| 1 Tribe | about 150 | Strength I 10, Warmth 30, Blessing 60 (Grip II is free) | 100 |
| 2 Village | about 450 | Strong Arms 40, Grip III 60, Rain 80, Strength II 100 | 280 |
| 3 Town | about 800 | Grip IV 150, Calm Waters 180, Lift Buildings 200, Guiding Light 200 | 730 |
| 4 Launch | about 1,400 | Steady Hand 200, Grip V 250, Strength III 300, Part the Clouds 400 | 1,150 |

If the bot can afford a power more than about 5 minutes before its region or job is needed, its cost goes up.

## 7. The relationship with the hand

The people know the hand is real, can see it, and deal with it directly \[CORE\]. There is no myth layer pretending you might not exist. What changes over the game is how they feel about you and how they speak to you.

### Trust, per person \[CORE\]

Each person holds a trust level from 0 to 5. Placing them on work they like, granting their wishes, warming them, and saving them from danger raises it. Dropping them somewhere pointless, ignoring wishes, and losing their loved ones lowers it slightly. Trust shows as a small hand icon on their hover card.

| Trust | How they act when you hover |
| --- | --- |
| 0 Afraid | Scatter from your shadow, cover their eyes when lifted |
| 1 Wary | Freeze and watch the hand |
| 2 Curious | Look up, point, call others to look |
| 3 Fond | Wave, smile when lifted |
| 4 Devoted | Reach up to be picked, bring you things |
| 5 Friend of the hand | Works 25% faster, gives better gifts, leads prayers, can be a foreman |

Children are born at their parents' average trust, so a village's attitude is inherited.

### Wishes: how they talk to you \[CORE\]

People show thought bubbles with icons (not words in Era 1, words from Era 3). Wishes come in three sizes:

- **Personal:** "I want to fish", "Put me with Ona", "I'm cold". Grant by placing or warming them. Small faith, big trust.
- **Family:** "We need a bigger home", "Our child is sick". Usually a build plot or a job.
- **Village dreams:** the milestone projects (section 5). They appear as a shared dream above the shrine, drawn by the people, and stay until done. These are the game's goals, so there's no separate quest list.

### Gifts \[CORE\]

People leave gifts at the shrine, and the gifts change with the era: flowers and carved hands (1), painted pots and woven cloth (2), illuminated books and a clockwork hand (3), a photograph of the village and a model rocket (4). Every gift can be lifted for faith, or **kept**: kept gifts go on a shelf in the Village Book, a little museum of the relationship \[PROPOSED\].

### The hand symbol, through the ages \[CORE\]

The image of an open hand is the game's recurring motif and the setup for the ending:

1. Era 1: a handprint in ochre on the cave wall by the first fire, then carved on the shrine.
2. Era 2: painted on pots and on the temple doors.
3. Era 3: in the stained glass of the observatory and on the town flag.
4. Era 4: on the mission patch and the rocket's side. The crew touch it before they board.

### The shrine grows with them \[CORE\]

Cairn (Era 1), then shrine, temple (Era 2), great hall of the hand (Era 3), launch tower (Era 4). Each is built where the last stood, so the place they built to talk to you becomes the place they leave from.

### Memories and disagreements \[PROPOSED\]

- **Memories:** notable things you did are logged and retold: "the night the hand lifted Pim from the flood". Elders tell them at the fire, and they're kept in the Village Book. Cheap to build and very good for attachment.
- **Disagreements:** once per era the people want something you might not, such as felling the old grove or damming the river. You can ignore it, help, or block it by lifting their tools away. They'll grumble and eventually do it their way. This adds friction to the relationship, not a morality meter.

## 8. Threats, setbacks and failure

Threats exist to give the hand something to *do* under pressure, and to make the people need you. They are never a fail state. **\[CORE\]** There is no game over: the worst case is a hard season, a lost building, or a grieving family.

### 8.1 Design rules for threats

- **Telegraphed.** Every threat is announced before it lands (howls at dusk, black clouds on the horizon, a smoke plume, a cough that spreads). The player always gets a window to act.
- **Answered with the hand.** Each threat has a hand answer (scoop people to shelter, flick a wolf, carry water to a fire, lift a boulder off a trapped worker). It is a skill check on the one verb, not a menu.
- **Answered by preparation.** Each threat also has a build answer (palisade, granary, well, fire brigade, clinic). Good planning makes a threat smaller; it never makes it vanish entirely, so the hand always matters.
- **Escalates by era, never spikes.** Threat strength is tied to era and population, not elapsed time, so a slow player is never punished.
- **Loss is personal and small.** A death is one named person with a memorial, never a mass wipe. A burned building leaves a ruin you can rebuild at half cost.
- **\[CORE\] Safety net.** If population ever falls to 1, wanderers arrive within a day. If food hits zero, the berry bushes by the cave never run dry, so there is always a job to place people on. The game can always recover.

### 8.2 Threats per era

| Era | Threat | Warning | Hand answer | Build answer | Worst outcome |
| --- | --- | --- | --- | --- | --- |
| 1 Tribe | Wolves at night | Howls at dusk, eyes in the treeline | Flick wolves away; carry people into huts | Fire, palisade, torch-bearers | One person injured or killed |
| 1 | Cold snap | Frost creeping across the ground, people shivering | Warmth power; carry people to the fire | Huts, fire tended, furs | People slow and sick for a day |
| 1 | First winter | Season banner, food ticker shows days left | Lift stored food to the fire; place people on the evergreen bushes | Food store, smokehouse | Hunger, lower joy |
| 2 Village | Flood | River rises, rain clouds build for a day | Lift people and goods to high ground; Calm Waters (later) | Levee, raised granary | Fields and a few huts washed out |
| 2 | Drought | Cracking soil, wilting crops | Rain power; carry water from the river | Well, irrigation ditch | Poor harvest |
| 2 | Bears | Claw marks, then a bear at the edge of the woods | Strength II lifts and relocates a bear (fun moment) | Watchtower, hunters' lodge | Livestock lost, someone hurt |
| 2 | Crop blight | Brown patches spread field to field | Place the herbalist and helpers on sick fields before it spreads | Crop rotation, herbalist | One field lost |
| 3 Town | Town fire | Smoke, bell rings | Carry water buckets, pull people from windows, Lift Buildings to make a firebreak | Fire brigade, stone houses, wells | A district burns |
| 3 | Sickness | One cough, then a few; the Book shows who's ill | Carry the sick to the clinic; quarantine by placement | Clinic, clean water, sewer | Elders or babies may die |
| 3 | Storms | Dark sky, wind lines | Shield people with the open palm; Lift Buildings to pull boats and carts to shelter | Storm cellars, sturdy roofs | Roofs torn, boats lost |
| 4 Launch | Workplace accidents | Machinery sparks, a crane sways | Catch a falling worker, lift a girder off someone | Safety rules guild, guard rails | One injury, a halted line |
| 4 | Smog | Haze rises, joy drops, people cough | Carry workers to new clean industry; place foresters on new parks | Filters, rail, parks | City-wide joy and health drop |
| 4 | Launch scrub | Countdown halts with a fault light | Lift the stage back to the gantry; place the right engineer | Test stand, redundant systems | Delay of a few minutes, gentle disappointment |

### 8.3 Failure states, in order of severity

1. **Inconvenience:** a job pauses, someone sulks, a log rolls away. Fixed by the hand in seconds.
2. **Setback:** a building lost, a harvest ruined, a few sick. Costs time and resources, never progress milestones.
3. **Grief:** a named person dies. Memorial stone appears, family mourns for a day (lower joy, slower work), the Book records it. **\[PROPOSED\]** Descendants occasionally visit the memorial.
4. **Crisis:** population collapses or food runs out. Safety net kicks in (wanderers, the evergreen berry bushes). The era clock does not reset.

There is no fifth level. **\[CORE\]** Milestones, unlocked powers and trust earned are never lost.

### 8.4 Difficulty settings **\[PROPOSED\]**

- **Gentle:** threats announce earlier, deaths are replaced by injuries, safety net triggers at 3 people.
- **Normal:** as described.
- **Harsh:** shorter warnings, deaths happen, winters are longer. No other changes; the game stays winnable.

## 9. The goodbye

The ending is the reason the whole game exists. Everything before it, the names, the lineage, the trust, the gifts, is set-up for about eight minutes at the launch tower. **\[CORE\]** It is played, not watched: the hand does every important action.

### 9.1 What makes it land

- **They chose to go.** The rocket is the village's own dream (it appears as a Village Dream in Era 4, written by them, not a task from you). The hand helps; it does not send them away.
- **You know the crew.** The four crew members are always descendants of the first two people. The Book shows the line from the first night to them.
- **It is mild.** Nobody dies, nothing is lost, there is no tragic twist. It is a parent watching a child leave for university, not a funeral.
- **The hand is not left alone.** Most of the people stay. The city lives on. Free play continues.

### 9.2 Beat sheet

| # | Beat | What the player does | What happens |
| --- | --- | --- | --- |
| 1 | The last evening | Free, with a soft prompt to visit the shrine | Music thins. People gather at the launch plateau in the clothes of their trade. The shrine has become the base of the launch tower. |
| 2 | Crew selection | Place four crew members on the crew bench (the game suggests the four most trusting descendants of the first two; trust 5 is ideal, not required) | Each one, when lifted, says a single line of gibberish plus a subtitle ("I remember the stories of the cave") |
| 3 | The gifts | People line up and offer the hand one item each from every era (a carved hand, a painted pot, a clockwork hand, a model rocket) | Gifts float into a ring around the hand; they go up with the crew as a time capsule |
| 4 | Into the capsule | Lift each crew member and place them in the capsule seat, one at a time | The same lift sound as the very first night. The hand's shadow covers the capsule. |
| 5 | The weather turns | Clouds roll in. Hold **Part the Clouds** over the plateau through the countdown | The countdown only runs while you hold. Let go and it pauses gently (no failure). |
| 6 | Liftoff | Hold, then release when the crowd cheers | Rocket rises through the gap you opened. The camera stays low, with the people. |
| 7 | The wave | Optional: raise the open hand | Everyone in the city turns and waves at the hand and at the sky. Babies are held up. |
| 8 | The light | Watch | A small light blinks twice in the night sky. The crowd recognises it as the old hand-sign from the cave painting. |
| 9 | The lineage | Watch | The family tree draws itself from the first two names down to the crew, then fades into the stars. |
| 10 | The hand lowers | Lower the hand to rest on the ground | The hand rests; a child climbs onto a finger. Credits roll over the city at night. |

### 9.3 After the credits

- **\[CORE\] Free play.** The game returns to the city at dawn. All powers stay. No more dreams are required; the Book shows a "What next?" page with optional village wishes (gardens, monuments, a museum of gifts).
- **\[PROPOSED\] Epilogue.** After 15 to 20 minutes of free play, a message arrives from the crew: a light from the stars draws the hand-sign. The people build a statue of the crew. It plays a short reprise of the main theme.
- **\[STRETCH\] New Valley.** A New Game+ that starts with two new people and keeps the museum of gifts from the last run.

### 9.4 Things the ending must never do

- Kill anyone, or imply the planet is dying.
- Make the hand vanish or weaken.
- Take control away for more than about 20 seconds at a time.
- Rely on text walls. Subtitles are single short lines.

## 10. World and map

**\[CORE\]** One hand-authored valley, about 1.2 km across when fully open, that the player sees grow from a single clearing to a coastal city with a launch plateau. No procedural generation: every region is placed so that each power reveals it at the right moment.

### 10.1 Regions and what opens them

| # | Region | Era | Opened by (section 6) | What's there | First fun thing |
| --- | --- | --- | --- | --- | --- |
| 0 | The Clearing | 1 | Start | Cave, fire pit, berry bushes, a stream | Lifting the branch to shelter the first two people |
| 1 | Valley Floor | 1 | Grip II (a group of 3 hauls away the fallen trunk) | Meadow, deer, flint, more trees | First hunt with four people |
| 2 | Western Meadow | 1 | Strength I (the hand lifts the fallen logs) | Wanderers, stone, rich bushes, the wolves' den | Planting the first wild grain |
| 3 | East Bank | 2 | Reach (place people across the great river) | Clay, copper ore, fish, bears | Working the far bank, then building the bridge with a group |
| 4 | Southern Plains | 2 | Rain (the dry plains turn green) | Flat land for farms, horses | Watering your first big field from the sky |
| 5 | Hill Quarry | 2 to 3 | Strength II (the hand clears the rockfall) | Stone, iron, ledges, the hilltop where the Observatory stands | Placing quarrymen on ledges only the hand can reach |
| 6 | Coast and Islands | 3 | Calm Waters (the sea can be crossed by boat) | Harbour site, islands with rare ore, a lighthouse | Lifting a boat into the sea and stilling the waves for it |
| 7 | Northern Pass | 4 | Strength III (the hand lays rail across the gorge) | Coal, high meadows, the oil seep | Setting a whole rail car down on the far side |
| 8 | Launch Plateau | 4 | The rocket dream (the Clearing's rock shelf is built up) | The old shrine, now the base of the launch tower | Stacking rocket stages where the cave once was |

### 10.2 How the map expands

- Locked regions are visible but dim, behind a clear physical blocker (a fallen tree, a boulder field, a fog bank, a storm wall). **\[CORE\]** The player always sees the next thing to open.
- Opening a region is a short moment: blocker removed by the hand, camera eases out, music swells, new region lightens over two seconds.
- The camera bounds widen with each region. Zoom-out limit grows with era, so the city never feels cramped.

### 10.3 Layout principles

- The Clearing stays the heart of the map. The cave becomes the shrine, then the temple, then the base of the launch tower: the ending happens where the game started.
- The river runs west to east and is the spine; the coast is south-east; mountains frame the north.
- Each region has one landmark visible from anywhere (a giant tree, the quarry cliff, the lighthouse, the observatory dome) so the player can orient by eye.
- Buildings snap to a soft grid of 2 m; roads and paths are drawn by the people walking (desire lines become dirt paths, then roads, then streets).

### 10.4 Time of day and seasons

- **\[CORE\]** Timings follow section 5: a day is 60 to 90 seconds of light plus a short night, and a season is about 4 minutes. A full year is roughly 16 minutes, so Era 1 sees about three winters.
- Each season changes the map visibly: spring meltwater and blossom, summer gold grass, autumn colour and harvest piles, winter snow that slows walking.
- **\[PROPOSED\]** Weather is tied to powers: Rain (Era 2) and Part the Clouds (Era 4) give the hand direct control.

## 11. UI, UX and onboarding

**\[CORE\]** The world is the interface. The player should be able to play most of the game with the HUD hidden, reading state from the people and the land: smoke from a chimney means the fire is lit, a thin person is hungry, a person tapping their foot is idle.

### 11.1 The HUD

| Element | Where | What it shows | Notes |
| --- | --- | --- | --- |
| Dreams panel | Top left | The current 1 to 3 Village Dreams, each with a small picture and progress pips | This is the goal list. Click to pan the camera to it. |
| Stores strip | Top centre | Food, wood, stone and the era's key material, plus days of food left | Only shows resources that exist in this era |
| Faith and powers | Bottom left | A faith glow ring, and power icons that light up when affordable | Click a power to unlock it; a short animation shows what it opens |
| Time | Top right | Day/night dial, season icon, speed (pause, 1x, 2x, 3x) | Space pauses |
| Alerts | Right edge | Small portrait cards: "Ama is hungry", "Wolves at dusk" | Click pans to the cause; fades after 10 s |
| Hand tooltip | Next to the hand | What you're holding and where it would go ("3 people, Haul log 3/3") | The key multi-grab clarity fix |

### 11.2 The Village Book (F1)

A hand-drawn book that grows with the village. Tabs: **People** (portrait, name, age, skills, trust, wish, parents and children), **Family Tree** (zoomable, from the first two), **Dreams** (current and completed, with the date), **Memories** (gifts, firsts, memorials), **Powers** (unlocked and next, each with the region it opens). **\[PROPOSED\]** Every page is written in the people's voice: "On the twelfth day the hand brought us the log for our first fire."

### 11.3 Placement clarity (answers your playtest note)

- Hovering a job with people in hand shows **slot pips** (●●○ = 2 of 3) and a ghost of where each person will stand.
- A group job that is short of hands pulses gently and shows a tiny "needs 3" badge.
- Grip is shown as fingers on the hand: one finger raised per held person, up to the grip limit, then a fist glow.
- First time the player can grab two, a contextual prompt appears once: "Drag across people to scoop them." No other tutorial text for it.

### 11.4 Onboarding: the first ten minutes

| Minute | What happens | What the player learns |
| --- | --- | --- |
| 0 | Storm night. Two people huddle under a cliff, rain pouring. A branch has fallen across the cave mouth. | Mood, and that they are small |
| 0 to 1 | A hint glow on the branch. The player lifts it away; the two run inside the cave. They look up at the hand. | Lift and place; they see you |
| 1 to 3 | Dawn. One of them points at berry bushes. Place them there. | Placing on a job |
| 3 to 5 | A log for the fire needs 2 carriers. With a grip of 1, the player places them one after the other before the first gets bored. | Multi-grab, with a real reason |
| 5 to 8 | They light a fire and leave the first gift (a stone with a handprint). Faith appears, and the first power, Grip II, arrives free with a one-time scoop hint. | Gifts and faith |
| 8 to 10 | First Village Dream: "A shelter of our own." A third person (a wanderer) appears at the edge of the map. | Dreams are goals; the village grows |

No pop-up tutorial screens. **\[CORE\]** Every lesson is taught by a situation in the world.

### 11.5 Menus and options

- Title screen: the valley in the current save's era, slowly panning. Continue, New Valley, Load, Options, Credits.
- **\[CORE\]** Autosave every in-game dawn plus on quit; 3 manual slots.
- Options: mouse sensitivity, edge-pan on/off, invert rotate, UI scale (80 to 150%), subtitles on/off and size, colour-blind friendly alerts, screen shake off, music/SFX/voices volumes, difficulty (section 8.4), fullscreen/windowed, vsync, quality preset.
- **\[PROPOSED\]** Full key rebinding. **\[STRETCH\]** Controller support (left stick moves hand, triggers lift and place).

## 12. Art direction and assets

### 12.1 The look

**Warm low-poly diorama.** Chunky, rounded shapes, flat or gently graded colours, soft shadows, tilt-shift-friendly camera. Think *Kingdom for Keflings* meets *Townscaper* meets *Bad North*. It reads clearly at a distance (the camera sits high), runs well with 200 people, and is the style with the most free, matching, high-quality assets available.

- **People** are small, big-headed, readable from 30 m: silhouette and clothing colour say their job. Faces are simple dots and a mouth, so emotion is carried by animation (wave, cheer, cower, sulk).
- **The hand** is the one realistic-ish object: a large, softly glowing, slightly translucent hand with a warm rim light. It never looks threatening. Its glow colour shifts subtly with each era (amber, gold, white, pale blue).
- **Scale** is the joke and the heart: the hand is about 12 people tall.

### 12.2 Era palettes

| Era | Palette | Materials | Light |
| --- | --- | --- | --- |
| 1 Tribe | Ochre, moss green, charcoal, firelight orange | Hide, wood, bone, stone | Low sun, long shadows, fire-lit nights |
| 2 Village | Wheat gold, terracotta, sky blue, white daub | Thatch, clay, timber, bronze | Bright mornings, pastel dusks |
| 3 Town | Brick red, slate grey, sea teal, stained-glass jewel tones | Stone, tile, iron, glass | Lamp-lit streets, lighthouse beam |
| 4 Launch | Steel, warm white, signal orange, deep night blue | Concrete, steel, glass, neon | Clean daylight, city glow at night, launch floodlights |

### 12.3 Asset sources

Only Claude produces and integrates assets for this project. Everything below is free with a licence that allows commercial use; CC0 means no credit is required, though we'll credit anyway.

| Role | Source | Licence | What we'd use |
| --- | --- | --- | --- |
| Primary | **Quaternius** (quaternius.com) | CC0 | Ultimate Nature pack (trees, rocks, plants), Medieval Village MegaKit (Era 2 to 3 buildings), Ultimate Animated Character pack (rigged villagers), Animated Animals (wolf, deer, bear, horse, sheep), Modular Sci-Fi and Spaceships (Era 4 and the rocket) |
| Fill | **Kenney** (kenney.nl) | CC0 | Survival Kit (Era 1 props, fire, tents), Pirate Kit (boats, harbour), City Kit Industrial and Commercial (Era 4), Space Kit (launch hardware), UI Pack and Game Icons, plus audio packs |
| Fallback | **KayKit** by Kay Lousberg | CC0 | Medieval Hexagon and Adventurers packs if a Quaternius piece is missing |
| Animation | **Mixamo** (Adobe, free account) | Free for use in games; raw files can't be redistributed | Carry, walk-with-load, hammer, chop, dig, cheer, wave, cower, sit. Retargeted to the villager rig and baked into the game files. |
| Built by Claude | Godot scenes and shaders | Ours | The hand (modelled from primitives with a custom glow shader), terrain, water, snow and season shaders, the shrine-to-tower set pieces, the cave painting, the Village Book UI art, all VFX |

**Consistency rule:** one primary pack per category so styles never clash, a shared colour palette applied through a single material library (every imported model gets its colours remapped to the era palette), and identical outline/shading on everything.

### 12.4 Getting the assets into the cloud build

The cloud network blocks quaternius.com, kenney.nl, itch.io and Mixamo. Two ways around it; **pick one in the rulings table**:

1. **You download, I collect.** You grab the listed zips into your Downloads folder (I'll give an exact checklist of about 10 links). I pull them in through the device connection (up to 400 MB per pull) and do the rest.
2. **Open the network.** In Project settings you add those hosts to the allowed list, and I fetch everything myself.

GitHub mirrors of some Kenney kits are reachable today, which is enough to start M1 while the rest arrives.

### 12.5 Art production order

1. Hand, terrain and water shaders (Claude, M1).
2. Era 1 kit: nature, cave, huts, fire, villagers, wolf (M2).
3. Era 2 kit: farms, village buildings, animals, boats (M3).
4. Era 3 kit: stone town, harbour, lighthouse, observatory (M4).
5. Era 4 kit: city, industry, launch tower, rocket stages (M5).

Each era kit is reviewed as screenshots in this project before it goes into a build you play.

## 13. Audio and music

### 13.1 Music direction

One **main theme**, a simple, hummable five-note motif (the "hand motif") that grows with the people. In Era 1 it's a lone flute and hand drum; in Era 2 strings and lute join; Era 3 brings a small orchestra and church bells; Era 4 adds piano and soft synth pads. At the launch, the full arrangement plays once, then drops back to the lone flute for the wave.

**\[CORE\] Adaptive layers.** Each era has one long calm piece split into stems (base, rhythm, melody, colour). The game fades layers in and out:

| State | Layers playing |
| --- | --- |
| Night, quiet | Base only |
| Day, people working | Base + rhythm |
| Hand holding people | + melody (it feels like the music leans in when you act) |
| Threat warning | Rhythm swaps to a tense variant; melody drops |
| Milestone or region opened | A short stinger of the hand motif, then all layers for 20 s |

Season colours: winter thins to strings and bells, autumn adds warmth, spring adds birdsong-like woodwind.

### 13.2 Music sources (pick in rulings)

| Option | What it is | Pros | Cons |
| --- | --- | --- | --- |
| A. **Composed by Claude** | I write each piece as MIDI with stems, render through a free General MIDI soundfont (e.g. FluidR3, MIT licence) with FluidSynth in the cloud | Real adaptive stems; one consistent theme across eras; no licence worries | Sounds like a good soundfont, not a live orchestra |
| B. **Curated library** | Kevin MacLeod (incompetech, CC-BY 4.0) and CC0 / CC-BY tracks from OpenGameArt | Polished recordings | No shared theme, no stems, so adaptive layers become cross-fades; needs credits |
| C. **Hybrid** (recommended) | Claude composes the main theme and the adaptive era pieces (A); curated tracks (B) fill menus, the credits and free play | Best of both | Two styles to blend |

**Ruled: C, Hybrid.** Claude's own compositions come first. Royalty-free tracks are only suggested to you where a gap remains, and you approve each one.

Kevin MacLeod tracks require this credit in-game and in the store page: `"Track Title" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 License http://creativecommons.org/licenses/by/4.0/`. Every asset and track, CC0 included, goes in `CREDITS.md` and the in-game credits.

### 13.3 Villager voices

**\[CORE\]** Gibberish, Simlish-style. Each person gets a voice pitch from their age and a random seed, so the same person always sounds the same. About 40 short syllables recorded as synth vowels (or generated procedurally, as the prototype already does) and stitched into phrases. Emotions: happy chirp, question, worry, cheer, sad hum. The language **\[PROPOSED\]** slowly gains a few real words per era ("Hand!" in Era 2, "Thank you" by Era 4) so the relationship literally becomes clearer.

### 13.4 Sound effects

- **Hand:** soft whoosh on move, a warm "lift" chime that rises in pitch with how many people are held, a soft thump on place, a deeper thud for heavy objects. The lift chime is the game's signature sound.
- **Work:** chopping, knapping, hammering, sawing, digging, cart wheels, forges, cranes, all on a soft rhythm so a busy village sounds musical.
- **World:** wind, rain, river, sea, birds by season, crickets at night, wolves, bears, bells, city hum.
- **Sources:** Kenney audio packs (CC0), Sonniss GDC bundles (royalty-free, no credit needed), and procedural synthesis by Claude for UI and the hand.

### 13.5 Mixing rules

People's voices duck the music slightly; threat warnings are always audible above everything; nothing is louder than the launch.

## 14. Technical architecture

### 14.1 Engine and targets

- **Godot 4.6** (the version the prototype uses), GDScript throughout. **\[CORE\]** Windows 64-bit first, shipped as a .zip. **\[PROPOSED\]** Linux build for free (same export); Steam Deck later.
- **Renderer:** move from Compatibility (prototype) to **Forward+** for the real game: better shadows, SSAO, volumetric fog for storms and the launch, and GPU particles. Compatibility stays as a low-end fallback option. Cloud screenshots keep working through the Vulkan software path or the fallback.
- **Performance target:** 200 people plus animals at 60 fps on a mid-range PC (GTX 1060 / RX 580 class) at 1080p; 30 fps floor on integrated graphics on the Low preset.
- **Minimum spec** (to confirm in M1): 4-core CPU, 8 GB RAM, DirectX 12 or Vulkan-capable GPU.

### 14.2 Project structure

```
res://
  autoload/   Game.gd, Clock.gd, Faith.gd, Village.gd, Save.gd, Audio.gd, Events.gd
  data/       jobs/*.tres  buildings/*.tres  powers/*.tres  eras/*.tres  dreams/*.tres
  scenes/     world/  people/  sites/  hand/  ui/  fx/
  scripts/    person/  hand/  sites/  threats/  ai/
  assets/     models/  anims/  textures/  audio/  fonts/  (each with LICENSE notes)
  tests/      bot/  unit/
```

### 14.3 Data-driven design

**\[CORE\]** Everything a designer would tune lives in Godot Resources (`.tres`), not code, so balancing never needs a rebuild of logic:

| Resource | Key fields |
| --- | --- |
| `JobDef` | id, era, slots (min/max people), skill family, inputs, outputs, work time, weight, needs tool, group bonus curve |
| `BuildingDef` | id, era, footprint, cost, build slots, upgrades\_to, jobs it hosts, capacity, joy/warmth radius |
| `PowerDef` | id, faith cost, prerequisite, what it unlocks (region id, job ids), unlock cutscene |
| `EraDef` | id, palette, music set, dream list, gate project, threat table, population band |
| `DreamDef` | id, text, picture, condition (script expression or checklist), reward |
| `ThreatDef` | id, era, warning time, trigger rules, hand answers, build answers |

A debug **balance sheet** (CSV export of all defs) lets us review numbers in a spreadsheet.

### 14.4 Core systems

- **Simulation tick** at 10 Hz for needs, work progress and AI decisions; rendering and the hand run every frame. Speed 2x and 3x scale the tick, not the frame.
- **People:** a hierarchical state machine (the prototype's IDLE / HELD / DROP / WORK / SHELTER / DEAD grows to add EAT, SLEEP, SOCIAL, LEARN, FLEE, CELEBRATE). Utility scoring picks what an idle person does. LOD: people far from the camera skip animation updates and use cheaper skeletons.
- **Pathfinding:** NavigationServer3D with a baked navmesh per region, re-baked in the background when buildings are placed. Avoidance on for crowds.
- **Hand:** its own scene with a physics ray, a held-list, and a weight budget (Strength). All hand actions emit events so tutorials, sounds and dreams hook in without coupling.
- **Event bus** (`Events` autoload) for loose coupling: `person_placed`, `job_completed`, `dream_done`, `region_opened`, `threat_started`, etc.
- **Rendering at scale:** MultiMesh for trees, crops and rocks; instanced buildings; one shared material library with the era palette as a global shader parameter.

### 14.5 Saving

**\[CORE\]** Versioned JSON save (with a migration function per version), written to the user folder. Autosave at each dawn and on quit, rotating 3 autosaves, plus 3 manual slots. A save holds every person (name, age, family links, skills, trust, wish), every building and site, stores, unlocked powers, regions, dreams, the Book's memories, and the clock. Target size under 2 MB at 200 people.

### 14.6 Testing and QA

- **Headless bot** (already working in the prototype) grows into a full auto-player that can reach each era gate. It runs in the cloud on every build and reports time-to-gate, deaths, stalls and fps. This is how we keep era lengths at 45/60/70/60 minutes without long manual playtests.
- **Screenshot tests** for each era at fixed times, posted here for your review.
- **Unit tests** (GUT) for save/load round-trips, job maths and dream conditions.
- **Your playtests** at each milestone gate are the real test; bot QA is kept short.

### 14.7 Build and delivery

Cloud-built Windows export, zipped, delivered to this project's files (and copied to your Downloads folder in pieces under 25 MB if you like). Source zip with every build. **\[PROPOSED\]** A private GitHub repo for history and backups, once you connect one.

## 15. Production plan and milestones

**\[CORE\]** The game is built one era at a time, and nothing moves to the next milestone until you have played the build and said go. Each milestone ends in a Windows .zip, a source zip, screenshots, and a one-page "what to try" note.

### 15.1 Milestones

| Milestone | Goal | What's in it | Your playtest checks |
| --- | --- | --- | --- |
| **M1 Foundation** | The bones, rebuilt properly | New project structure (14.2), data Resources, people state machine with needs, the new hand (drag-scoop, slot pips, weight), navmesh, save/load, first real assets (nature + villagers + hand), main theme sketch | Does the hand feel good? Is multi-grab obvious? Do the people feel alive? |
| **M2 Era 1 complete** | A full 45-minute tribe era | Storm-night opening, start with 2 people, wanderers and births, all Era 1 jobs and group jobs, seasons and the first winter, wolves and cold, Grip II, Strength I, Warmth and Blessing, with the first two opening the Valley Floor and Western Meadow, the Stone Circle gate, Era 1 music with adaptive layers, the Village Book v1 | Is the pacing right this time? Is every power a fun moment? Do you remember the names? |
| **M3 Era 2 Village** | Farming, families, the first generation change | Era transition, ageing and elders, farming and bread, pottery, bronze, herding, boats; flood, drought, bears, blight; East Bank, Southern Plains, Hill Quarry; Temple of the Hand gate | Does the jump in complexity feel earned? Does a generation passing land? |
| **M4 Era 3 Town** | Stone town, foremen and the coast | Foremen (autonomy dial), stone and iron, harbour and islands, fire and sickness, the Observatory on the quarry hilltop as the gate | Can you still manage 100+ people with one hand? Is it still *your* village? |
| **M5 Era 4 Launch + goodbye** | The city, the rocket, the ending | Guilds, industry, rail and the Northern Pass, the launch plateau, rocket stage stacking, the full goodbye sequence, free play, credits | Does the ending land? Would you change a beat? |
| **M6 Polish and release** | A finished game | Balance pass with the bot, options and accessibility, performance at 200 people, bug sweep, credits and licences, optional epilogue | Is it done? |

### 15.2 How each milestone runs

1. Build in parallel where it splits cleanly (for example, art kit, systems, and music in separate threads).
2. The headless bot plays the build and checks timing, stalls and fps. QA stays short.
3. A screenshot set and a short note land in this project.
4. You play it and comment. Anything you rule out is cut before the next milestone starts.

### 15.3 Risks

| Risk | Why it matters | Plan |
| --- | --- | --- |
| Asset access | The cloud can't reach the asset sites | Resolve in the rulings table before M1 (12.4) |
| Mixed asset styles | Packs from different artists can clash | One primary pack per category, shared palette remap (12.3) |
| 200 people at 60 fps | Godot's per-node cost adds up | Sim tick at 10 Hz, animation LOD, MultiMesh, measured from M1 |
| Late-game micromanagement | One hand, many people | Foremen and guilds (section 3), Fill gesture, alerts that pan the camera |
| Pacing drift | Eras too fast or too slow (your Era 1 note) | Bot measures time-to-gate on every build; tuning lives in data files |
| Scope | Four eras plus an ending is a lot | Era-by-era gates; anything tagged STRETCH can be cut without touching CORE |

## 16. Rulings needed

Pick a ruling for each line. **In** builds it as written, **Out** cuts it, **Later** parks it after release, **Change** means tell me what in the Notes column or a comment. Anything left Undecided is built as written.

| # | Decision | Section | Tag | My pick | Ruling | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Start with 2 people; wanderers and births grow the tribe | 3, 11.4 | CORE | In | In |  |
| 2 | Four eras at about 45/60/70/60 minutes, roughly 4 hours to the rocket | 5 | CORE | In | In |  |
| 3 | Named people age, have children and die (a new generation every 20 to 30 minutes) | 3 | CORE | In | In | Opportunity to name first 2 if desired. Random event where villagers may "pray to receive a name for their baby" |
| 4 | Grip levels 1, 3, 5, 10, 20 with group jobs that need them | 2, 4 | CORE | In | In |  |
| 5 | Strength by weight, up to lifting whole buildings and rocket stages | 2, 6 | CORE | In | In | only for organizational purposes. Should be optional if the player chooses not to move buildings. |
| 6 | Seasons of about 4 minutes, so Era 1 has about three winters | 5, 10.4 | PROPOSED | In | In |  |
| 7 | Foremen in Era 3 and guilds in Era 4 take over routine placement | 3 | CORE | In | In |  |
| 8 | Faith from gifts and work buys powers; it is never drained | 6 | CORE | In | In |  |
| 9 | Village Dreams are the goal system (three per era, the third is the gate) | 5, 7 | CORE | In | In |  |
| 10 | Gifts per era, kept in a museum | 7 | PROPOSED | In | In |  |
| 11 | The 16 powers and the regions each one opens | 6, 10 | CORE | In | In |  |
| 12 | Threat list per era, no game over, safety net at 1 person | 8 | CORE | In | In |  |
| 13 | Deaths can happen on Normal (Gentle turns them into injuries) | 8.4 | PROPOSED | In | In |  |
| 14 | Ending beat sheet: crew are descendants, you hold Part the Clouds through countdown | 9 | CORE | In | In |  |
| 15 | Epilogue: a light from the stars after free play | 9.3 | PROPOSED | In | In |  |
| 16 | New Valley (New Game+ that keeps the museum) | 9.3 | STRETCH | Later | Later |  |
| 17 | Village Book written in the people's voice | 11.2 | PROPOSED | In | In |  |
| 18 | Art style: warm low-poly diorama, glowing hand | 12.1 | CORE | In | In |  |
| 19 | Asset packs: Quaternius primary, Kenney fill, KayKit fallback | 12.3 | CORE | In | In |  |
| 20 | Mixamo animations (you download these with a free Adobe account, whichever asset route you pick) | 12.3 | PROPOSED | In | In |  |
| 21 | Asset route: you download to Downloads, or open the network in settings | 12.4 | CORE | Open the network | In | I will open the network as you see fit, I will need proper explanation on this when the time comes |
| 22 | Music: A Claude-composed, B curated library, or C hybrid | 13.2 | CORE | C hybrid | In | C, Hybrid, but start with your own compositions first and recommend some royalty free tracks when needed. |
| 23 | Gibberish voices that learn a few real words each era | 13.3 | PROPOSED | In | In |  |
| 24 | Switch renderer to Forward+ (Compatibility kept as fallback) | 14.1 | PROPOSED | In | In |  |
| 25 | Linux build alongside Windows | 14.1 | PROPOSED | Later | Later |  |
| 26 | Full key rebinding | 11.5 | PROPOSED | In | In |  |
| 27 | Controller support | 11.5 | STRETCH | Later | Later |  |
| 28 | Private GitHub repo for history and backups | 14.7 | PROPOSED | In | In |  |
| 29 | Milestones M1 to M6, each gated by your playtest | 15 | CORE | In | In |  |
