# roomwalk

*[Гайд по-русски →](README.md) · [Contributing](CONTRIBUTING.md)*

**Что это.** Плагин для Claude Code. Строит скролл-шапку для сайта бизнеса: камера идёт по
одному сгенерированному помещению, останавливается у каждой вещи, которую бизнес продаёт,
и на каждой остановке всплывают его собственные настоящие фотографии.

**Что нужно:** Claude Code, Python 3 и аккаунт Higgsfield с кредитами. Генерация платная —
черновик обходится примерно в 25–80 кредитов.

**Установка:**

```bash
claude plugin marketplace add Aironzak/instagram
claude plugin install roomwalk@roomwalk
```

Дальше `/roomwalk:connect` — напечатает ссылку для входа в Higgsfield, — перезапуск Claude Code,
и `/roomwalk:start`.

**Two scroll-driven heroes. Pick by whether the offer is a place or a thing.**

**`roomwalk`** — send it your website. It reads the site, proposes a walk through one
generated space with a stop at each thing you sell, and builds it.

**`exploded`** — one product on pure black that comes apart as you scroll. A single unbroken
shot: assembled at the top, floating in pieces at the bottom. **No joins at all**, because
there is only ever one segment — which removes the failure mode that costs the most time in a
walk.

---

## Which one

| | `roomwalk` | `exploded` |
| --- | --- | --- |
| The offer is | a range, in a place | one object |
| Fits | joinery, clinic, restaurant, gym, atelier, detailing, florist | watch, bottle, sneaker, chair, tool, jar, lamp |
| Segments | 4–6, joined | **one**, played forward then back |
| Seams to fix | yes, and they are the hard part | none |
| Ground | a lit interior | pure black, so the hero has no edge |
| Draft cost | 60–80 credits | 25 credits (65 for the 1080p final) |

In `roomwalk` the generated space is the **stage** and your own photographs are the **proof**,
surfacing at the stop that matches their category — nobody is shown a rendered thing and told
it is yours. In `exploded` the object must be **your** product photograph; the explosion is
generated from it, never the product itself.

Purely digital businesses are the wrong fit for both, and the skills say so.

---

## Install

Paste this into Claude Code. That is the whole setup.

> Поставь плагин roomwalk: `claude plugin marketplace add Aironzak/instagram`, потом
> `claude plugin install roomwalk@roomwalk`. Затем подключи Higgsfield — запусти в фоне
> `connect_higgsfield.py` из плагина и дай мне ссылку для входа. После этого начни
> roomwalk и спроси у меня ссылку на сайт.

It installs itself, hands you a Higgsfield sign-in link, and then asks one question:

> *Пришлите ссылку на сайт мастерской.*

Send the link. It reads the site — categories, how many photographs sit behind each,
prices, the line they repeat about themselves — and comes back with a plan and a price:

> Посмотрел сайт. Мастерская делает столешницы (155 фото), подоконники (118), столы (55),
> шкафы (32) — всего 618 работ. Есть калькулятор с настоящими ценами: от 14 300 ₽/м².
> С 2003 года, рейтинг 5,0.
>
> Предлагаю проход по одной комнате: столешница → подоконник → откос → стол → шкаф,
> в конце шкаф открывается. На каждой остановке всплывают ваши настоящие фотографии.
>
> Черновик 480p — около 70 кредитов, минут двадцать. Делаем так?

You say yes. It builds.

If the site can't be read, it says so and asks for two things instead: what the shop
makes, and a few photographs of finished work. It will not guess the business from a
domain name, and it will not build without photographs.

Restart Claude Code once after the sign-in so the Higgsfield tools load.

Prefer it by hand:

```
/plugin marketplace add Aironzak/instagram
/plugin install roomwalk@roomwalk
/roomwalk:connect
/roomwalk:start
```

---

## What you need

| | |
| --- | --- |
| **Higgsfield MCP** | Add `https://mcp.higgsfield.ai/mcp` through the connector UI at claude.ai. **Not** via `claude mcp login` — see below. |
| **Python 3** | `python3 -m pip install --user pillow numpy imageio-ffmpeg`. Runs on **macOS, Windows and Linux**; `imageio-ffmpeg` carries its own ffmpeg, so nothing is installed system-wide. |
| **Real photographs** | Your own — pulled off your site automatically. Without them there is no proof layer. |
| **Credits** | A five-stop draft runs about 60–80 credits at 480p. |

### The connector, specifically

`claude mcp login higgsfield` always fails with *"Issuer mismatch in authorization
response (RFC 9207)"*. Higgsfield's metadata declares `issuer: https://mcp.higgsfield.ai`
while the redirect carries `iss=https://clerk.higgsfield.ai` from their upstream Clerk.
Claude Code rejects that correctly and there is no flag to disable the check. Their
advertised device-code server, `fnf-device-auth.higgsfield.ai`, returns 404 on every
endpoint, so that route is dead as well.

`/roomwalk:connect` works around it. It runs the same authorization-code + PKCE flow with
the same `state` check and skips only the `iss` comparison — a mix-up protection that
matters when a client talks to several authorization servers, where here there is exactly
one, taken from Higgsfield's own metadata. Then it writes the token into the user-scope
MCP config as a static bearer header.

Because the header is static, the token eventually expires. `--refresh` renews it without
a new sign-in; `--status` reports what is configured. Adding the connector through the
claude.ai UI also works if you would rather click than run a script.

---

## What's inside

```
skills/roomwalk/
  SKILL.md                    the pipeline, the rules, the failure modes
  tools/extract_frames.py     video → numbered frames + manifest (imageio-ffmpeg)
  tools/measure_seams.py      how visible is each join, in numbers
  tools/measure_flicker.py    per-frame brightness jitter and loop-seam distance
  tools/blend_seam.py         soften a mild join without spending credits
  tools/preview_hero.py       composite a frame with gradients + caption to PNG
  tools/brightness_curve.py   chart exposure drift per frame and per segment
  tools/stabilise_exposure.py pull every frame to a common median
  tools/_frames.py            shared frame reading and luma maths
  tools/*.swift               the original macOS-only versions, kept for reference
  tools/connect_higgsfield.py Higgsfield sign-in that works around the RFC 9207 bug
  web/scroll_frames.js        canvas scroll engine with a pacing timeline
skills/exploded/
  SKILL.md                    one object on black, one shot, no joins
commands/
  connect.md                  /roomwalk:connect — Higgsfield sign-in
  start.md                    /roomwalk:start — ask for the link, read the site, propose
  walk.md                     /roomwalk:walk — go straight to building the walk
  explode.md                  /roomwalk:explode — build the product hero
```

---

## What space you get

| Business | The space | Typical stops |
| --- | --- | --- |
| Joinery, furniture | one room of a house | worktop · sill · table · cabinet fronts |
| Perfumery | a boutique | shelf of flacons · tester bar · gift packaging · counter |
| Cosmetology, dental | reception and one treatment room | reception · chair · product shelf · quiet corner |
| Restaurant, bakery | dining room to pass | window seat · counter display · open pass · bar |
| Car detailing | one workshop bay | lift · polishing bay · wheel wall · finished car |
| Flowers, ceramics | a studio | workbench · shelving · packing table · window |
| Fitness, spa | one hall plus a corner | equipment row · weights · treatment room · lockers |
| Clothing, tailoring | atelier or shop floor | fabric rolls · mannequin · fitting mirror · rail |

---

## The three rules that decide whether it works

**Lock both ends.** Every transition gets a `start_image` *and* an `end_image`. Without
the end anchor the model invents the arrival, and you get the two classic failures: an
object grows into frame that was not there before, and the camera reverses to find its
subject.

**Chain from the real tail.** The model rarely lands exactly on the anchor. Start the
next segment from the previous segment's *actual* last frame, not the pristine anchor —
the join becomes continuous by construction while `end_image` still controls arrival.

**One room.** Measured on a real build: transitions inside one room joined at 1.07–1.86×
the normal frame-to-frame change, invisible. The three that walked through a doorway into
a second room tore at 6.3×, 11.4× and 8.4×. If the brief needs more categories than one
room holds, put the extras in the catalogue below the hero.

---

## Three things that decide whether it feels smooth

**Stabilise the exposure.** The model relights the scene as it goes — measured drift across
five segments was +15, +15, +1, −11, −37. Invisible at playback speed; scrubbed slowly it
reads as *"the sun appears and then goes away"*. `stabilise_exposure` pulls it to +1.7, +0.8,
+1.6, −0.7, −5.4, with the clamp keeping genuinely dark places dark.

**Give travel more scroll than the holds.** The instinct is backwards. Hold 1 against travel
3 puts 30 % of the scroll into the stops and 70 % into moving. Doing it the other way round
was the first thing a client called sticky.

**Load progressively and in parallel.** Every eighth frame across the whole run first, then
denser, eight requests in flight — and draw the nearest loaded frame rather than nothing.
A sequential loader means the first minute of scrolling lands on frames that have not
arrived and the page reads as broken.

**Never read an unknown viewport as mobile.** Before layout, `innerWidth` is 0 and
`matchMedia('(max-width: 768px)')` answers yes — on desktop that halved the frame set and
halved the section height. Waiting for layout via `requestAnimationFrame` is worse: in a
hidden tab it never fires and the wait hangs forever. Treat an unknown width as unknown and
default to the full set.

**Don't hide copy for a reveal without a safety net.** If the observer doesn't run — tab
minimised, timers throttled, a script that threw earlier — the reader is left with a blank
screen. Reveal everything still hidden after 2.5 s, whatever the cause.

---

## Two numbers to hit

**120 frames per 8-second segment.** Sixty samples at 7.5 fps and scrubbing shows steps.

**9–10 px of scroll per frame.** Section height in screens ≈ `(frames × 10 / viewport) + 1`.
Six hundred frames on an 833 px viewport is about 8 screens. The same frames stretched
over 15 screens gives 28 px per frame and visibly steps.

Pacing is not shot — it lives in the `timeline` option. Generate an even camera move,
then set the rhythm in five numbers. Dwell 3 against travel 2 gives roughly a fourfold
speed difference, and retuning never costs a regeneration.

---

## Weight, said out loud

Six hundred frames at 864 px JPEG is about 32 MB. Fine for a prototype, heavy for
production. WebP or AVIF takes 30–50 % off; narrower frames stretched by CSS take more;
a sprite atlas collapses the request count. Or scrub a real `<video>` — a 30-second 1080p
H.264 is roughly 4 MB, six times lighter, at the cost of seek precision in Safari.

---

## Honesty, and where it becomes a hard stop

The space is generated. Your photographs are the proof layer, and the footer says plainly
that the interior is styling rather than a photograph of your premises.

**It generates the environment, never the outcome.** A room, a shelf, a counter, a chair,
light on a surface — yes. A result you are selling — no:

- **No faces, no bodies, no skin.** For anything cosmetic, medical, dental, fitness or
  aesthetic this is absolute. A generated "after" is a fabricated clinical claim, and
  advertising one is illegal in most jurisdictions regardless of a disclaimer.
- No before-and-after of any kind.
- No generated food presented as your menu.
- No generated products carrying your branding.
- No certificates, diplomas, licences or awards in frame.

For regulated businesses the hero shows the premises only, and every claim and result on
the page comes from your own material. A visitor who books a procedure because of a
rendered face is a worse outcome than no hero at all.

---

MIT.
