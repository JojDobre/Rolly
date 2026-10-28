# Rolly

Mobilná plošinovka v Godote 4.4. Hráš za guľovú postavičku (Kenney Shape Characters),
zbieraš hviezdy a mince a prechádzaš levelmi plnými funkčných blokov a mobov.
Súčasťou hry je **editor svetov a levelov**.

## Spustenie

1. Stiahni **Godot 4.4** (verzia Standard): https://godotengine.org/download
2. V Godote daj **Import** a vyber `project.godot`.
3. **F5** spustí hru.

## Ovládanie

| Akcia | Klávesnica | Mobil |
|---|---|---|
| Chôdza | ← → / A D | šípky vľavo dole |
| Skok (dlhšie držanie = vyšší, najviac 3 bloky) | medzerník / Z / J | okrúhle tlačidlo |
| Rebrík hore / páčka | ↑ / W | šípka hore |
| Rebrík dole | ↓ / S | šípka dole |
| Zoskočiť z plošiny | dole + skok | dole + skok |
| Pauza | Esc / P | tlačidlo pauzy |

## Postavička

Vyberáš ju v hlavnom menu: 5 farieb × 4 tvary (guľa, oblý štvorec, kocka, kosoštvorec).
Tvár mení výraz podľa toho, čo robíš (beh, skok, pád, zranenie, potápanie, cieľ), ruky gestikulujú.
Má 3 srdcia zdravia. Po strate všetkých príde o život (10 životov, +1 každých 30 minút, 100 mincí = +1 život).

## Predmety a ich funkcie

**Terén** (štýl podľa sveta): zem (rohy sa vyberú samé), plošiny, cez ktoré sa dá vyskočiť zospodu, svahy, steny, dosky, mosty.

**Terén na skrýše a podzemie**
- Tajná stena: vyzerá ako zem, ale dá sa cez ňu prejsť. Keď do nej hráč vojde, spriehľadní sa. Dá sa nakresliť aj cez predmet, napríklad cez hviezdu, ktorá je potom schovaná v stene.
- Stena podzemia / stena hradu: tmavé pozadie jaskyne. Je to vrstva, takže mince, moby a ďalšie predmety na nej ju nezmažú. Guma zmaže najprv predmet, potom stenu.

**Bloky**
- Rozbitná tehla: rozbiješ ju hlavou zospodu alebo bombou. Je svetlejšia ako pevná tehlová stena.
- Skrytý blok: nie je ho vidieť a dá sa cezeň prejsť. Keď doň hráč udrie hlavou zospodu, objaví sa a vyhodí zvolený obsah.
- Blok s mincou / s 5 mincami: úder hlavou vyhodí mincu.
- Blok s prekvapením: vyhodí zvolený predmet (srdce, drahokam, mincu, moba).
- Blok s mobom: vypustí moba.
- Padajúci blok: po stúpení sa zatrasie, spadne a po chvíli sa vráti.
- Miznúci most: chvíľu po stúpení zmizne a o 3 s sa objaví znova.
- Krabica: dá sa tlačiť a stáť na nej.

**Zbieranie**
- Mince: bronzová 1, strieborná 2, zlatá 5.
- Hviezdy: v každom leveli presne 3, určujú hodnotenie.
- Srdce: +1 zdravie.
- Drahokamy: červený +1 život, modrý rýchlosť, zelený vysoký skok, žltý neporaziteľnosť.

**Mechanizmy**
- Kľúč (4 farby): po zobratí zmiznú všetky zámky rovnakej farby.
- Tlačidlo: po stúpení prepne farebné bloky svojej farby na zvolený čas, potom sa vrátia.
- Páčka (pri nej stlač hore): natrvalo prepne farebné bloky a pohne výťahmi svojej farby.
- Výťah: po prepnutí páčky sa posunie hore alebo dole o zvolený počet dlaždíc.
- Prechodové dvere (4 farby): pri dverách stlač hore a prejdeš k druhým dverám rovnakej farby, napríklad do tajnej miestnosti pod zemou.
- Pohyblivá plošina: jazdí tam a späť vodorovne alebo zvisle o zvolený počet dlaždíc. Susedné plošiny sa spoja do jednej.
- Pružina: vystrelí hráča vysoko.
- Pás: posúva všetko, čo na ňom stojí.
- Rebrík a lano: lezie sa po nich hore a dole.
- Bomba: po dotyku sa zapáli a o 2 s vybuchne. Zničí moby, tehly a krabice v okruhu, zapáli iné bomby a zabije hráča v dosahu.

**Nebezpečné**
- Bodce, blok s bodcami, kaktus, hríby, píla: zraňujú.
- Láva: zabije hneď.
- Voda: dá sa v nej plávať, ale po 8 s pod vodou sa hráč utopí (ukazovateľ dychu).
- Ohnivá guľa: vyskakuje hore a dole.
- Závažie: spadne na hráča pod ním.

**Moby** (33)
- Na väčšinu sa dá skočiť.
- Ohnivý a pichľavý sliz, ryby, píly, duch a vysoké hady sa skočením poraziť nedajú.
- Slimák sa schová do ulity a ulitu môžeš kopnúť do ostatných mobov.
- Žaba skáče k hráčovi, netopier visí, kým neprídeš blízko, a duch sa hýbe, len keď sa naň nepozeráš.

## Svety

**Zelené kopce** (svet 1), levely inšpirované Super Mariom:

| Level | Dĺžka | Čo v ňom je |
|---|---|---|
| 1-1 Zelené kopce | 206 | bloky, piliere, diery, tajná miestnosť pod zemou (červené dvere na pilieri), hviezda schovaná v schodoch |
| 1-2 Podzemná chodba | 200 | jaskyňa, bomba pred tehlovou stenou, plošina nad priepasťou, netopiere, tajná cesta po tehlovom strope, schovaný tunel |
| 1-3 Nad oblakmi | 180 | stĺpy a oblaky nad priepasťou, pohyblivé a padajúce plošiny, miznúce mosty, pružiny, neviditeľné bloky k hviezde |
| 1-4 Hrad | 190 | láva s ohnivými guľami, drviče, píly, závažia, výťah ku kľúču, skrýša v strope, zamknutá brána |
| 1-5 Jazero a jaskyňa | 300 | svah, jazero s rybami a hviezdou na dne, jaskyňa s tlačidlom a rebríkom ku kľúču, páčka s výťahom, zvislý výťah nad priepasťou |

Každý level má 1 checkpoint na 150 dlaždíc dĺžky.

Levely generuje `python3 tools/world1.py` a dajú sa ďalej upravovať v editore.

`python3 tools/reach.py data/worlds/<svet>.json [--map]` overí, či sa dá dostať ku každej hviezde, kľúču a do cieľa. Simuluje chôdzu, skoky, rebríky, vodu, pružiny, dvere, rozbíjanie tehál, skryté bloky, kľúče, tlačidlá, páčky a bomby. S `--map` vypíše mapu miest, kam sa hráč dostane.

## Editor

Hlavné menu → **Editor levelov**.

1. **Nový svet**: názov, štýl blokov (tráva, hlina, piesok, sneh, kameň, fialová), pozadie, hudba.
2. **Nový level**: otvorí editor s pripravenou zemou, štartom a cieľom.
3. **V editore:**
   - **Paleta dole** je rozdelená na kategórie. Terén sa kreslí v štýle sveta.
   - **Nástroje vľavo:** Kresliť, Guma, Posun (alebo dva prsty / pravé tlačidlo myši), Upraviť (nastavenie položeného predmetu). Priblíženie robíš štipnutím, kolieskom alebo tlačidlami +/−.
   - **Cesta moba:** nástroj Upraviť → ťukni na moba → „Nastaviť cestu“ → ťukni na začiatok a koniec. Chodci sa na krajoch cesty otáčajú, letci, ryby a píly lietajú tam a späť (aj šikmo).
   - **Nastavenia predmetu** sú v paneli vpravo: farba páčky a výťahu, obsah bloku, smer, vzdialenosť, dosah bomby, čas tlačidla…
   - **Kontrola** hneď ukáže, čo v leveli chýba: kľúč bez zámku, tlačidlo bez blokov, páčka bez výťahu, chýbajúci štart, cieľ alebo hviezdy. Tlačidlom „Položiť“ rovno vyberieš chýbajúci predmet aj so správnou farbou.
   - **Skúsiť** spustí level bez straty životov. Z pauzy alebo po dokončení sa vrátiš do editora.
   - **Uložiť** uloží level. Level s chybami sa uloží ako rozpracovaný a v zozname na hranie sa neukáže, kým ho neopravíš.

### Kde sa svety ukladajú

- Na telefóne: `user://worlds/*.json`, teda len v tom telefóne.
- Pri spustení z Godot editora na počítači: `data/worlds/*.json` v projekte. Tieto svety sa dodávajú s hrou, takže ich stačí commitnúť.

Ukážkový svet sa dá pregenerovať príkazom `python3 tools/demo_levels.py`.

## Hudba a zvuky

- Nárazy sú z Kenney Impact Sounds, melódie pri udalostiach z Kenney Music Jingles.
- Hudba na pozadí je CC0 z OpenGameArt, autori sú v `assets/licenses/music.txt`.
- Playlisty a melódie nastavíš v `scripts/game_state.gd`.

## Testy

Automatické testy bežia v Godote bez okna:

```
godot --headless --path . --script res://tests/mechanics.gd    # testy mechaník (aj kontrola 5 levelov sveta 1)
godot --headless --path . --script res://tests/editor_test.gd  # testy editora
godot --headless --path . --script res://tests/compile_all.gd  # kontrola všetkých skriptov
```

Screenshoty (potrebujú displej, napríklad `xvfb-run`): `tests/screenshot.gd` a `tests/ui_shot.gd`.

## Štruktúra

| Priečinok / súbor | Obsah |
|---|---|
| `scripts/catalog.gd` | všetky predmety a moby: názov, kategória, funkcia, parametre |
| `scripts/level_loader.gd` | postaví level z dát |
| `scripts/level_validator.gd` | kontrola párov a povinných prvkov |
| `scripts/player.gd`, `player_visual.gd` | hráč a jeho vzhľad |
| `scripts/entities/` | správanie blokov, predmetov a mobov |
| `scripts/game.gd`, `hud.gd` | priebeh levelu a rozhranie |
| `scripts/menu.gd`, `scripts/editor/` | menu a editor |
| `scripts/ui_theme.gd` | plochý vzhľad menu, panelov a editora (font Baloo 2, ikony Kenney UI Pack) |
| `scripts/content.gd` | ukladanie svetov a levelov |
| `data/worlds/` | svety dodávané s hrou |

## Reklamy

V `scripts/game_state.gd` sú pripravené funkcie `show_rewarded_ad()` (+1 život) a `maybe_show_interstitial()` (po leveli).
Zatiaľ sú to atrapy. Neskôr ich napojíme na AdMob.

## Grafika a licencie

Kenney (CC0):
- New Platformer Pack
- Shape Characters
- Platformer Art Extended Enemies
- Platformer Pack Remastered (čiastočky tehál)
- Mobile Controls
- UI Pack
- Impact Sounds
- Music Jingles

Font Baloo 2 je pod licenciou SIL Open Font License.

Licencie sú v `assets/licenses`.
