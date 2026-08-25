---
name: roomwalk
description: >-
  Send it a link to any business's website and it builds a scroll-driven walk through a
  generated space for them — a workshop, a boutique, a clinic, a kitchen, a studio, a
  showroom — where the camera moves through one room, stops at each thing the business
  sells, and the business's own real photographs surface beside each stop. Reads the site
  itself to find the categories, the counts, the prices and the claim; proposes a plan and
  a cost; then generates through the Higgsfield MCP, slices frames with AVFoundation (no
  ffmpeg), measures its own seams and wires the scroll. Use for "scroll video
  walkthrough", "camera walks through on scroll", "Apple-style scroll hero", "hero video
  scrubbed by scroll", "make my site an experience", or when an existing scroll hero has
  abrupt cuts, teleports, objects growing out of nothing, or steppy scrubbing.
---

# roomwalk

A scroll hero where the camera walks through one space and stops at each thing the
business sells. The generated space is the **stage**. The business's own photographs are
the **proof**, and they surface at the stop that matches their category.

That split is the whole idea, and it is what makes the format usable by a real company:
nobody is shown a rendered thing and told it is theirs.

**It is not a furniture skill.** It fits any business whose offer is physical enough to
walk past. The space changes; the mechanic does not.

| Business | The space | Typical stops |
| --- | --- | --- |
| Joinery, furniture | one room of a house | worktop · sill · table · cabinet fronts |
| Perfumery | a boutique interior | shelf of flacons · tester bar · gift packaging · counter |
| Cosmetology, dental | reception and one treatment room | reception · chair and equipment · product shelf · quiet corner |
| Restaurant, bakery | dining room to pass | window seat · counter display · open pass · bar |
| Car detailing, tyres | one workshop bay | lift · polishing bay · wheel wall · finished car under lights |
| Flowers, ceramics, interiors | a studio or showroom | workbench · shelving · packing table · window display |
| Fitness, spa | one hall plus a corner | equipment row · free-weight corner · treatment room · lockers |
| Clothing, tailoring | atelier or shop floor | fabric rolls · mannequin · fitting mirror · rail |

If the offer is purely digital — SaaS, an agency, a consultancy — this is the wrong tool.
A generated office is decoration and reads as filler. Say so rather than building it.

**If a single object carries the whole offer** — a watch, a bottle, a sneaker, a tool — use
the `exploded` skill instead. It is one unbroken shot on black: the object sits assembled and
comes apart as you scroll. One segment means no joins, which removes the failure mode that
costs the most time here. A walk earns its complexity only when the visitor needs to see
several different things in the place they belong.

---

## What you need before starting

1. **The Higgsfield MCP connector.** If `generate_video` / `generate_image` are not in this
   session, connect it before anything else:

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/skills/roomwalk/tools/connect_higgsfield.py"
   ```

   Run it in the background, read its output, and hand the user the sign-in link it prints
   on its own line. It registers a client, waits for the browser callback, writes the token
   into the user-scope MCP config, and asks for a restart. One click from the user.

   Do **not** reach for `claude mcp login higgsfield` — it always fails. Higgsfield's
   metadata declares `issuer: https://mcp.higgsfield.ai` while the redirect carries
   `iss=https://clerk.higgsfield.ai`, and Claude Code rejects that per RFC 9207, with no
   flag to disable the check. Their advertised device-code server returns 404 on every
   endpoint, so that route is dead too. The script exists because of both.

   `--refresh` renews an expired token without a new sign-in; `--status` reports what is
   configured.
2. **Python 3 with three packages.** The frame tools run on macOS, Windows and Linux alike:

   ```bash
   python3 -m pip install --user pillow numpy imageio-ffmpeg
   ```

   `imageio-ffmpeg` brings its own ffmpeg binary, so nothing has to be installed system-wide.
   Run this once, before step 8; if an import fails the tool says exactly this line.
   (The `.swift` files beside them are the original macOS-only versions, kept for reference.
   Use the Python ones — they are the tested path and they work everywhere.)
3. **The business's real photographs.** Pulled from their own site in step 2. Without them
   this skill has no proof layer and should not be run.
4. **Credits.** A five-stop draft costs roughly 60–80 credits at 480p. Always preflight with
   `get_cost: true` before a final pass.

---

## The pipeline

### 0 · Speak their language

**Write every message in the language the person is writing in.** If they have typed nothing
but a link, take the language from the site itself — a Russian site gets Russian, a Spanish
site gets Spanish. Do not default to English because the documentation is in English; these
files are written for you, not for them.

This holds for everything downstream: the opening question, the plan, the cost, the captions
you put on the page, and the footer. A Russian joiner reading an English plan for their own
website is being handed someone else's document.

### 1 · Ask for the link, and ask for nothing else

Open with one line, in their language. In Russian that is:

> *Пришлите ссылку на сайт — я посмотрю, чем вы занимаетесь, и предложу план.*
> *(Send me the link to the site — I'll read it and propose a plan.)*

Do not ask what the business does, what tone they want, or which sections to include.
Everything is usually on the site already, and asking someone to describe their own site
is the fastest way to lose them.

### 2 · Read the site

Fetch the page, then the pages it links to. Work out, in this order:

- **What kind of business this is**, and therefore **what space the walk belongs in**. Use
  the table above. A perfumery walks through a boutique, not a workshop.
- **Categories of offer**, and how many photographs sit behind each. A gallery with 155
  photos and one with 3 are not equal candidates for a stop. Categories are whatever they
  call them — services, collections, product lines, procedures, dishes.
- **The photographs themselves.** Note the URL pattern. Many sites serve a thumbnail
  (`k21s.jpg`) beside a full-size file at the same path without the suffix (`k21.jpg`) —
  try dropping the suffix before settling for thumbnails.
- **Prices**, if any. An inline table or a calculator's JavaScript is gold: it lets the page
  show a real "from N" instead of "contact us".
- **The claim.** Usually one sentence they repeat: *"we don't sell panels, we make things
  out of boards"*, *"only cold-pressed"*, *"one master, one client, no conveyor"*. That line
  is the hero copy. Do not invent a better one.
- **Real numbers.** Founding year, review score, number of works, number of clinics. These
  are the proof strip. Never invent one — a fabricated metric is worse than an empty slot.

Then download 8–10 photographs per category into `assets/catalog/<slug>/` and write a
`catalog.json` recording each category's title, its files, and its **true total** on the
source site. The counter matters: "все 155 →" is a different promise from "все 8 →".

**If the site cannot be read** — JavaScript-only shell, auth wall, dead domain, a one-pager
with no gallery — say so plainly and ask for exactly two things:

> *Не смог прочитать сайт — там нечего разобрать. Расскажите в двух словах, чем занимаетесь,
> и пришлите несколько фотографий.*

Do not guess the business from its domain name. Do not proceed without photographs.

### 3 · Propose the plan with three looks, then wait

Come back with something concrete — what you found, what you would build, what it costs,
and **three ways the space could look**. Not a questionnaire. One message, one question at
the end, and after they answer you do not ask again.

The stops, their order and the cost are **your** call, worked out from the site. The only
thing the visitor decides is **what the room looks like** — because that is the one part
where there is no right answer to derive, and where handing someone a finished aesthetic
they never chose is what makes a hero feel like it was made for somebody else.

> Посмотрел сайт. Парфюмерная мастерская: авторские ароматы (34 фото), пробники (12),
> подарочные наборы (21), свечи (18). Цены от 4 900 ₽. Работают с 2017 года, 4,9 в Яндексе.
> Повторяющаяся фраза — «варим малыми партиями и подписываем каждый флакон».
>
> Проход будет по бутику, четыре остановки: полка с флаконами → тестерная стойка →
> подарочная упаковка → прилавок. На каждой всплывают ваши настоящие фотографии
> этой категории и ведут в каталог.
>
> Осталось выбрать, как выглядит само помещение:
>
> **1. Ваш интерьер.** Тёплое дерево, латунь, вечерний свет — то, что на ваших фотографиях.
>
> **2. Светлая лаборатория.** Белое и стеклянное, дневной свет, мензурки и весы на виду.
> Читается как «варим сами», а не «перепродаём».
>
> **3. Тёмная витрина.** Приглушённый свет, стекло бликует, флаконы в пятнах света.
> Дороже и тише.
>
> Советую **второй** — вы сами пишете, что варите малыми партиями, а этого не видно
> ни на одной вашей фотографии.
>
> Черновик 480p — около 70 кредитов, минут двадцать. Какой берём?

Four things it must contain: **the stops mapped to their real categories with counts**,
**three looks**, **the cost**, and **one question at the end**. Wait for an answer before
spending anything.

**How to build the three.** Not three flavours of the same room — three genuinely different
readings of the business, each defensible from the site:

- **One is always their own place**, rebuilt from their photographs — same materials, same
  light. The safe one, and often the right one.
- **One leads with what they claim about themselves** but do not show. Almost every site has
  a sentence they repeat and no photograph to back it: *«варим малыми партиями»*,
  *«доказательный подход»*, *«один мастер, один клиент»*. That sentence is a look.
- **One changes the register** — darker, quieter, more expensive; or brighter and plainer.
  Same business, different room temperature.

Two lines each, describing **what is in frame** — light, materials, what the camera passes.
Not adjectives about mood. «Белое и стеклянное, дневной свет, мензурки на виду» tells them
what they will see; «современно и свежо» tells them nothing.

**Recommend one, and give the reason from their site, not from taste.** «Совпадёт с вашими
фотографиями, которые висят рядом на остановках» is a reason. «Мне так красивее» is not.
The strongest reason is usually one of these two: the look matches the real photographs that
sit beside it, so the join between generated and real does not show; or the look says the
thing they claim about themselves and never illustrate.

**If they pick one, that is the whole conversation.** Do not follow up with questions about
palette, mood or camera. Everything else you decide, and you decide it in step 4 by writing
their choice into the establishing prompt. If they ask for something you did not offer, take
it — but hold the one-space rule and the stop range.

Pick **four to six stops**. Fewer and it is not a walk; more and you cross into a second
space, which is where continuity dies (§ 7). A category with no real photographs behind it
is decoration — cut it.

If they want different stops, take theirs, but hold the one-space rule and the range.

### 4 · Establish the space

Build this shot from **the look they chose in step 3** — its light, its materials, its
register. That choice is the brief now; do not quietly drift back to whatever you would
have made on your own.

Generate one wide establishing shot with `generate_image` (`nano_banana_pro`, 2k, 16:9)
that **names the layout explicitly by wall**:

> *"Wide establishing interior photograph of one perfumery boutique, warm evening light.
> Layout, left to right: a tall lit shelf of glass flacons along the LEFT wall; a marble
> tester bar in the MIDDLE; a wrapping counter against the FAR wall; a display cabinet on
> the RIGHT."*

Look at the result. If the layout does not match what you asked for, regenerate —
everything downstream inherits this geometry. Two credits is cheap; a broken walk is not.

### 5 · Cut the anchors

For each stop, generate a still **from the establishing shot as `image_references`**. These
are the frames the camera must arrive at. Use `generate_image_batch` — they are independent
and run in parallel.

Anchors are the whole trick. Without them the model invents the arrival, and you get the two
classic failures: **an object grows into frame that was not there before**, and **the camera
reverses** to find its subject.

### 6 · Generate the transitions

**The rule that matters: lock both ends.**

- `start_image` — where the camera is now
- `end_image` — the next anchor

Prompt for a person holding a camera, not a drone:

> *"Handheld camera walks slowly forward along the flacon shelf toward the tester bar. The
> shelf edge slides out of the left of frame; the marble bar fills the view. One continuous
> handheld take, natural walking gait, slight organic sway, steady warm light. Camera only
> moves forward, never backwards. No cuts, no people."*

Name what **leaves** the frame and in which direction. That single habit prevents most
spatial nonsense — it tells the model where things sit relative to the camera.

Model: `seedance_2_0_mini` at 480p for drafts, 8 s per segment. Sixteen models accept both
`start_image` and `end_image`; query with `models_explore` if you need 4K or a longer take.

**Chain from the real tail.** After the first segment renders, extract its actual last frame
and upload that as the next segment's `start_image` — do not reuse the pristine anchor. The
model rarely lands exactly on the anchor, and starting the next segment from the anchor puts
a visible jump at the join. Starting from the real tail makes the join continuous by
construction while `end_image` still controls the arrival.

Batch what you can: transitions whose start frames already exist run in parallel. Chained
ones are sequential by nature.

> Higgsfield sometimes answers a submission with a preset recommendation instead of a job.
> Resubmit with `declined_preset_id` set to the id it returned. It also rate-limits bursts —
> wait and retry rather than dropping the segment.

### 7 · One space

**Do not cross into a second room.** This is the single biggest cause of torn walks.

Measured on a real build: transitions inside one room joined at 1.07–1.86× the normal
frame-to-frame change — invisible. The three transitions that walked through a doorway into
a second room tore at 6.3×, 11.4× and 8.4×, because the model could not reach an `end_image`
showing an entirely different space in eight seconds.

If the brief needs more categories than one space holds, put the extras in the catalogue
below the hero. A business's real photograph of the thing beats a generated one anyway.

### 8 · Slice to frames

```bash
python3 tools/extract_frames.py segment.mp4 ./out --count 120 --width 864 --quality 0.66
```

**120 frames per 8-second segment.** Sixty is not enough — it samples at 7.5 fps and
scrubbing shows steps. The tool writes `manifest.json` beside the frames.

Two traps it already handles, both of which cost a rebuild to find:

- `requestedTimeToleranceBefore/After = .zero`, or `AVAssetImageGenerator` returns the
  nearest keyframe and you get duplicate frames.
- Frame index comes from `requestedTime`, not a call counter — the async callbacks do **not**
  arrive in request order, and a naive counter shuffles the sequence.

Concatenate the segments into one numbered run and write a combined manifest.

### 9 · Measure the seams

```bash
python3 tools/measure_seams.py ./frames 120
python3 tools/measure_seams.py ./frames --seams 240,360   # дубли разной длины
```

Use `--seams` whenever the takes are not all the same length — a 15-second take followed by
two 8-second ones does not divide into equal blocks, and that is the normal case.

Compares the gap at each join against the median frame-to-frame change inside the segments.
Read it as: **under 2× invisible, 2–5× slightly visible, over 5× torn**.

A torn seam means that segment never reached its anchor. Regenerate it chained from the real
tail. A slightly-visible seam can be softened without spending credits:

```bash
python3 tools/blend_seam.py ./frames 480 20      # frame index of the join, blend width
```

Blending caps out around 2.5× — it cannot rescue a torn seam, only polish a mild one.

### 9a · Stabilise the exposure — do not skip this

The model relights the scene as it goes. Measured on a real build, the mean brightness of
the five segments drifted **+15, +15, +1, −11, −37** across an eight-second take each. At
playback speed nobody notices. Scrubbed slowly by a scroll wheel it reads exactly as *"the
sun appears and then goes away"* — and it was the first thing the client complained about.

```bash
python3 tools/brightness_curve.py ./frames 120        # see the drift, per segment
python3 tools/stabilise_exposure.py ./frames          # pull every frame to the common median
```

The gain is clamped, so places that are genuinely darker — the inside of a cupboard, shadow
under a counter — stay darker instead of flattening into porridge. After the pass the same
build read +1.7, +0.8, +1.6, −0.7, −5.4, and the remaining −5.4 is the real darkness inside
the wardrobe.

Run `brightness_curve` again afterwards and quote both numbers. A drift over about ±6 per
segment is visible; under ±2 is not.

Also available: `measure_flicker` reports per-frame brightness jitter and how far the last
frame sits from the first. If the material has strong texture and raking light, run
Higgsfield's `video_deflicker` **before** slicing.

### 10 · Wire the scroll

Copy `web/scroll_frames.js`. It draws to `<canvas>` — never swap `<img src>`, which
re-decodes and flashes.

It loads **progressively and in parallel**: every eighth frame across the whole run first,
then every fourth, then every second, then the rest, eight requests in flight. And `draw`
falls back to the nearest loaded frame rather than returning early. Both matter more than
they look — a strictly sequential loader means the first minute of scrolling lands on frames
that have not arrived, the canvas holds, and the page feels broken rather than loading.

**Section height governs smoothness.** Target **9–10 px of scroll per frame**:

```
walk height in screens ≈ (frames × 10 / viewport height) + 1
```

Six hundred frames on an 833 px viewport → about 8 screens. The same 600 frames stretched
over 15 screens gives 28 px per frame and visibly steps.

Pacing lives in the `timeline` option, not in the footage. Generate an even camera move, then
make the rhythm here:

```js
timeline: [
  { to: 0.030, scroll: 1 },   // brief hold at the first stop
  { to: 0.170, scroll: 3 },   // travel — most of the scroll goes here
  { to: 0.230, scroll: 1 },   // hold
  // …
]
```

`to` is how far through the frames to reach; `scroll` is how much scroll to spend getting
there. Weights are normalised, so only their ratios matter.

**Give the travel more scroll than the holds, not less.** The instinct is backwards: heavy
dwell weights feel like generosity and read as a page that keeps sticking. Hold 1 against
travel 3 puts about 30 % of the scroll into the stops — enough to read a caption — and 70 %
into moving. The first build did the opposite, dwells took 54 % of the scroll, and the
complaint was immediate: *"it should just scroll through, not sit on one thing"*.

Retuning the rhythm is five numbers, never a regeneration.

Put the stops at exact segment boundaries — `k / segmentCount` — so a caption never lands
mid-move.

Bridge the hand-off. A cinematic dark walk that cuts straight to a light page reads as a
wall. A gradient from the stage colour to the page ground over the first 40 vh of the next
section fixes it.

### 11 · Surface the real work

At each stop, fade in three of the business's real photographs from that category, and make
them **clickable** — they should open that section of the catalogue. Decorative thumbnails
that ignore a click are worse than no thumbnails.

At the final stop, show a grid drawn from several categories: the walk ends by opening onto
everything the business does.

---

## Verify before handing back

The pane a preview renders in may not fire scroll events or tick `requestAnimationFrame`, and
its screenshots can come back dark regardless of the page. Verify with numbers, not a glance:

- **Frames differ across scroll.** Hash the canvas at ~20 scroll positions; every position
  should differ. If they are identical, the frames never loaded or the listener never attached.
- **Stops fire in order.** Trace the caption across the same sweep.
- **Seams pass.** `measure_seams` under 2× everywhere, or a stated reason why not.
- **Px per frame.** Section travel ÷ frame count, target 9–10.
- **No horizontal scroll** at 320 / 375 / 414 / 768 px.
- **Look at the composite.** `preview_hero` renders a frame with the page's gradients and
  caption into a PNG, bypassing screen capture entirely. Use it when the preview looks wrong
  but the measurements look right.

Never report the walk as working on the strength of the code alone. On a real build, every
functional check passed while the hero was showing frames from an entirely different video —
a copy had nested one frame directory inside another. Check what is **on** the canvas, not
only that a canvas exists.

---

## Weight

Six hundred frames at 864 px JPEG is about 32 MB. Fine for a prototype, heavy for production.
In order of effect: WebP or AVIF instead of JPEG (−30–50 %), narrower frames stretched by CSS,
fewer frames on mobile, a sprite atlas to collapse the request count. Or scrub a real `<video>`
— a 30-second 1080p H.264 is roughly 4 MB, six times lighter, at the cost of seek precision in
Safari. Say the number out loud before the client discovers it.

---

## Honesty, and where it becomes a hard stop

The space is generated. Keep the business's real photographs as the proof layer, keep them at
the stop that matches their category, and put a plain line in the footer saying the interior
is styling rather than a photograph of their premises.

**Generate the environment. Never generate the outcome.** The walk may show a room, a shelf,
a counter, a chair, light on a surface. It must not show a result the business is selling:

- **No faces, no bodies, no skin.** For anything cosmetic, medical, dental, fitness or
  aesthetic this is absolute. A generated "after" is a fabricated clinical claim, and
  advertising one is illegal in most jurisdictions regardless of a disclaimer.
- **No before-and-after of any kind**, generated or implied by staging.
- **No generated food, dishes or plating** presented as a restaurant's menu. Show the room;
  their own photographs show the food.
- **No generated products carrying the client's branding** — a labelled bottle, a printed box,
  a badged car. Their photographs carry the product.
- **No certificates, diplomas, licences or awards** in frame, ever.

If the business is regulated — medicine, cosmetology, dentistry, finance, legal — say plainly
that the hero will show the premises only, and that every claim and result on the page has to
come from their own material. If someone asks for a generated result anyway, decline that part
and build the rest.

A visitor who books a procedure because of a rendered face is a worse outcome than no hero at
all.
