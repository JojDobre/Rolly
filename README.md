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
| Skok (dlhšie držanie = vyšší) | medzerník / Z / J | okrúhle tlačidlo |
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

**Bloky**
- Rozbitná tehla: rozbiješ ju hlavou zospodu alebo bombou.
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

## Editor

Hlavné menu → **Editor levelov**.

1. **Nový svet**: názov, štýl blokov (tráva, hlina, piesok, sneh, kameň, fialová), pozadie, hudba.
2. **Nový level**: otvorí editor s pripravenou zemou, štartom a cieľom.
3. **V editore:**
   - **Paleta dole** je rozdelená na kategórie. Terén sa kreslí v štýle sveta.
   - **Nástroje vľavo:** Kresliť, Guma, Posun (alebo dva prsty / pravé tlačidlo myši), Upraviť (nastavenie položeného predmetu). Priblíženie robíš štipnutím, kolieskom alebo tlačidlami +/−.
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
godot --headless --path . --script res://tests/mechanics.gd    # 53 testov mechaník
godot --headless --path . --script res://tests/editor_test.gd  # 17 testov editora
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
| `scripts/ui_theme.gd` | vzhľad menu a panelov (Kenney UI Pack, font Baloo 2) |
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
