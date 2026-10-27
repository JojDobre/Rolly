# Gulička – kostra hry v Godote

Fyzikálna plošinovka: gulička sa kotúľa po mape, zbiera hviezdy a dostáva sa do cieľa.

## Ako to spustiť

1. Stiahni si **Godot 4.4** (verzia „Standard“, nie .NET): https://godotengine.org/download
2. Spusti Godot, klikni na **Import** a vyber súbor `project.godot` z tohto priečinka.
3. Pri prvom otvorení Godot chvíľu importuje obrázky a zvuky.
4. Hru spustíš klávesom **F5**.

Ak Godot pri spustení vypíše chybu, skopíruj mi text z panela **Output** alebo **Debugger** a opravím ju.

## Ovládanie

| Akcia | Klávesnica | Mobil |
|---|---|---|
| Kotúľanie | ← → alebo A D | tlačidlá vľavo dole |
| Skok (dlhšie držanie = vyšší skok) | medzerník, ↑ alebo W | tlačidlo vpravo dole |
| Pauza | Esc alebo P | tlačidlo II |

Dotykové tlačidlá sa zobrazia len na zariadení s dotykovou obrazovkou.

## Čo už hra vie

- Gulička s fyzikou: kotúľanie, skok s odpustením tesne po zídení z hrany, sploštenie pri dopade, oči sledujú pohyb, žmurkanie, strach pri páde.
- 3 hviezdy v každom leveli. Najlepší výsledok sa uloží.
- 10 životov, nový život každých 30 minút (počíta sa aj pri vypnutej hre), +1 život za reklamu (zatiaľ atrapa).
- Bodce, pád do jamy, checkpointy, cieľová vlajka.
- Krabice, ktoré sa dajú tlačiť, kľúč a zámok na hádankové levely.
- Menu s výberom levelov. Ďalší level sa odomkne až po dokončení predchádzajúceho.
- Zvuky dopadu podľa sily nárazu, zatrasenie obrazovky a vibrácia pri tvrdom dopade.

## Ako robiť nové levely

Level je obyčajný text v `levels/level_XX.gd`. Jeden znak je jedna dlaždica (64 × 64 px):

```
.  prázdno        #  zem              =  tenká plošina
/  svah           P  štart            F  cieľ
*  hviezda        C  checkpoint       ^  bodce
B  drevená krabica   M  kovová krabica
K  kľúč           L  zámok            >  šípka (ozdoba)
```

- Všetky riadky musia mať rovnakú dĺžku.
- Každý level má mať presne 3 hviezdy, jeden štart `P` a jeden cieľ `F`.
- Svah `/` sa sám natočí smerom k susednému bloku zeme.
- Nový level pridáš tak, že skopíruješ `level_03.gd` ako `level_04.gd` a v `scripts/game_state.gd` zvýšiš `LEVEL_COUNT`.

Pre orientáciu: skok je vysoký asi 2 dlaždice (na 3 dlaždice sa už nedá vyskočiť, iba z krabice) a cez jamu širokú 4 dlaždice sa preskočí.
Náhľad levelov je v `levels_preview.png`. Po úprave levelu ho obnovíš príkazom `python3 tools/preview_levels.py`.

## Kde čo je

| Súbor | Čo robí |
|---|---|
| `scripts/ball.gd` | fyzika a ovládanie guličky (rýchlosť, výška skoku – dá sa meniť v Inspectore) |
| `scripts/ball_visual.gd` | vzhľad guličky (farby, oči, sploštenie) |
| `scripts/game.gd` | priebeh levelu: hviezdy, smrť, checkpoint, cieľ, kamera |
| `scripts/level_builder.gd` | z textovej mapy postaví level (kolízie, predmety, krabice) |
| `scripts/terrain_art.gd` | kreslí terén v štýle Red Ball: tráva, hlina, obrys |
| `scripts/background.gd` | pozadie: nebo, oblaky a kopce s paralaxou |
| `scripts/hud.gd` | rozhranie počas hry a panely (pauza, koniec levelu, došli životy) |
| `scripts/menu.gd` | hlavné menu a výber levelov |
| `scripts/game_state.gd` | životy, ukladanie, zvuky, miesta pre reklamy |
| `assets/world/` | vlastná grafika sveta, vygenerovaná skriptom `tools/generate_art.py` |
| `assets/` | ostatná grafika a zvuky (Kenney, GameArt2D – licencie v `assets/licenses`) |
| `assets/worlds/` | pripravené dlaždice pre svet Továreň a Vesmír |

## Reklamy

V `scripts/game_state.gd` sú dve pripravené funkcie:

- `show_rewarded_ad()` – reklama, ktorú si hráč spustí sám (+1 život). Zatiaľ dá odmenu hneď.
- `maybe_show_interstitial()` – reklama po leveli, ktorá sa dá hneď zavrieť. Zatiaľ nerobí nič.

Neskôr ich napojíme na AdMob (plugin „Godot AdMob“).

## Export na Android (neskôr)

- V Godote: Editor → Manage Export Templates → Download.
- Project → Export → Add → Android. V časti Permissions zaškrtni **Vibrate**, inak nebude fungovať vibrovanie.
- Potrebuješ Android SDK a JDK 17. Návod: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html

## Ďalšie kroky

1. Vyskúšať a doladiť pocit z guličky (rýchlosť, skok, odraz).
2. Svet 2 (Továreň) so železnými guľami a svet 3 (Vesmír) s otočenou gravitáciou.
3. Boss každých 15 levelov.
4. Duch (záznam najlepšieho pokusu) a denná výzva s rebríčkom.
5. Obchod so skinmi guličky.
