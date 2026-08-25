---
name: exploded
description: >-
  Build a scroll-driven product hero from a single unbroken shot on pure black — the object
  sits assembled, and as you scroll it comes apart along its own axes into a floating
  exploded view. One take, no cuts, no seams to measure, because there is only ever one
  segment. Generates through the Higgsfield MCP with the first and last frame both locked,
  slices frames with AVFoundation (no ffmpeg), and scrubs them on a canvas. Use for "product
  landing page", "scroll explodes the product", "Apple-style product hero", "exploded view on
  scroll", "watch/bottle/shoe/tool landing page", or whenever a single object is the whole
  story and a walkthrough would be overkill.
---

# exploded

One object on pure black. Scroll, and it takes itself apart.

This is the sibling of `roomwalk` and the simpler of the two. Where a walk crosses a space
in several takes and every join has to be anchored, measured and sometimes rescued, this is
**one continuous shot**. There is nothing to join. The failure mode that costs the most time
in the walk — a torn seam — cannot occur here.

Reach for it when a **single object carries the offer**: a watch, a bottle of scent, a
sneaker, a chair, a hand plane, a coffee grinder, a jar of cream, a lock, a lamp. Reach for
`roomwalk` instead when the offer is a **range** and the visitor needs to see several things
in the place they belong.

---

## Why the black background is not a style choice

Every asset sits on pure black, and so does the page. That means the hero has **no edge**. A
walkthrough hero ends at a hard line where the footage stops and the page begins, and that
line reads as a wall — bridging it takes a gradient and still shows. Here the frames simply
dissolve into the page ground, because they are the same colour.

It also makes the frames compress far better: large flat black areas cost almost nothing in
JPEG, so a 700-frame sequence lands much lighter than the same count of a lit interior.

---

## What you need before starting

1. **The Higgsfield MCP connector.** If `generate_video` / `generate_image` are not in this
   session, connect it first:

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/skills/roomwalk/tools/connect_higgsfield.py"
   ```

   Hand the user the sign-in link it prints. `claude mcp login higgsfield` does not work —
   see the `roomwalk` skill for why.
2. **Python 3**, for the frame tools: `python3 -m pip install --user pillow numpy imageio-ffmpeg`.
   Works on macOS, Windows and Linux; `imageio-ffmpeg` carries its own ffmpeg.
3. **A photograph of the real product**, if the product is real. See § Honesty.
4. **Credits.** Measured on `seedance_2_5`, 10 seconds, both ends anchored: **25 credits at
   480p, 65 at 1080p**. Always run the draft first — the 480p tells you whether the motion is
   right, and a wrong motion at 1080p is 65 credits gone. Preflight with `get_cost: true`.

---

## The pipeline

### 1 · Ask for the product, and for a photograph of it

> *Что показываем? Пришлите фотографию изделия — лучше на простом фоне — и я соберу героя,
> в котором оно разбирается на части по скроллу.*

If the product is real and purchasable, **its photograph must come from the client**. If it
is a concept, a category illustration, or the client explicitly has nothing, generate the
base image and say plainly in the handover that the object shown is a representation.

### 2 · Asset 1 — the object, assembled

If the client supplied a photograph, put it on black first — `remove_background`, then
composite onto `oklch(0% 0 0)`. If you are generating it, ask `nano_banana_pro` for exactly
this shape of image:

> *"A studio-grade product photograph of <object>, shown at a three-quarter angle revealing
> both <face> and <side>. Pure black background with zero ambient light bleed, no reflections
> on the surface, no cast shadow. The object is fully assembled. Shot as if for a high-end
> print campaign — clinical precision, no stylisation."*

The three phrases that matter: **pure black background**, **no ambient light bleed**, **no
cast shadow**. Without them you get a floor plane, and a floor plane makes the object look
like it is standing in a room rather than floating in the page.

### 3 · Asset 2 — the same object, apart

Generate with **asset 1 as `image_references`**, never from scratch. This is what keeps the
parts recognisably the same object:

> *"Using the provided reference: deconstruct the object into a precise exploded-view
> diagram. Each component — <name them, in order along the axis> — floats apart from its
> assembled position along its natural mechanical axis, with uniform spacing. Deliberate and
> symmetrical, like a technical illustration. Pure black background. All parts keep their
> original finish and material. No labels, no lines, no graphic overlays."*

**Name the components yourself.** "Deconstruct it" gives you shrapnel; naming the bezel, the
crystal, the dial, the movement plate, the caseback gives you an exploded view. For a
worktop: the boards, the glue lines, the reinforcing splines, the edge profile, the finish
layer. For a bottle: the cap, the collar, the atomiser, the tube, the glass, the base.

Look at the result. If the parts do not read as the same object, regenerate — everything
downstream inherits this.

### 4 · Asset 3 — one shot, both ends locked

**This is the whole trick, and it is one call:**

- `start_image` — asset 1, the assembled object
- `end_image` — asset 2, the exploded arrangement

```
model: seedance_2_5     mode: omni_reference      duration: 10–20 s
resolution: 480p draft / 1080p final              aspect_ratio: 16:9
generate_audio: false
```

**`mode: 'omni_reference'` is not optional.** Without it the call is rejected outright:
*«mode 't2v' does not accept reference media; start_image and end_image are only allowed for
mode 'omni_reference'»*. The default mode is text-to-video and silently ignores nothing — it
refuses with a 422.

The prompt describes the *journey between two frames the model already has*, so it can only
choose how to get there:

> *"The object floats in a pure black void, fully assembled, with no environment, no ground
> plane, no ambient reflections. The camera begins at a front-right angle and orbits slowly
> clockwise in one smooth uninterrupted arc. About halfway through, the object begins a
> seamless mechanical deconstruction: each component separates along its natural axis with
> deliberate, weighted momentum. Parts drift outward in radial symmetry, as if gravity had
> been selectively reversed. Slow, cinematic and precise — never chaotic. By the end all
> parts hang in a balanced exploded arrangement, still against the black void."*

Because both ends are pinned, the model cannot invent an arrival, cannot reverse to find its
subject, and cannot grow a new element into frame — the three failures that cost the most in
a multi-segment walk. **There are no seams to measure. Skip the seam tooling entirely.**

`seedance_2_5` reaches 30 seconds, which is far more than this needs. Ten seconds at 24 fps
is 240 source frames — plenty for a 700-frame sequence after slicing.

### 5 · Slice, then check the void — don't reflexively stabilise

```bash
# нарезка — тот же инструмент, что и в roomwalk
python3 ../roomwalk/tools/extract_frames.py hero.mp4 ./frames --count 240 --width 1280 --quality 0.7
```

On black, the frames are small — a flat background costs almost nothing — so you can afford
more of them and a wider frame than a walkthrough allows.

```bash
# график экспозиции
python3 ../roomwalk/tools/brightness_curve.py ./frames
```

**Mean frame brightness rises across every exploded take, and that is usually correct.** As
the object opens up there is simply more lit metal in frame — on the reference build it went
14.5 → 20.4, and every point of that came from the brass movement coming into view. Running
`stabilise_exposure` on that would darken the late frames to match the early ones, dimming
the movement exactly where it is the whole point of the shot.

The number that decides it is the **corner** brightness, not the mean. Sample a small square
in each of the four corners across the take:

- **Corners flat** (they sat at 0.1–1.6 of 255 for the whole reference take) → the lighting
  never moved, the mean rose because the content did. **Do nothing.**
- **Corners drift** → the model relit the void. Now `stabilise_exposure` is the right call,
  and so is checking the corner value against the page background before shipping.

Sample the *corners*, not a border strip around the whole frame. A strip catches the object
the moment a part floats up to the edge: on the reference take the top-centre strip read 1.5
early and 124 later, which looks exactly like a catastrophic black-lift and is nothing of the
kind. Corners stay empty from the first frame to the last.

### 6 · Scrub it

Copy `../roomwalk/web/scroll_frames.js`. Same engine, but here the setup is simpler because
there are no stops:

```js
const seq = new ScrollFrames({
  canvas: document.querySelector('#hero'),
  scroller: document.querySelector('.hero-section'),
  dir: './frames',
  manifest: './frames/manifest.json',
  fit: 'contain',   // see below — this is the whole reason the black ground pays off
  zoom: 1,
  // no timeline — one continuous move deserves a continuous, even mapping
});
seq.start();

// Портрет: кадр 16:9 по contain съёживается в полоску.
const portrait = window.matchMedia('(max-aspect-ratio: 1/1)');
const setZoom = () => { seq.zoom = portrait.matches ? 1.75 : 1; seq.redraw(); };
setZoom();
portrait.addEventListener('change', setZoom);
```

**Use `fit: 'contain'`, not the default `cover`.** A walkthrough needs `cover` — an interior
that stops short of the edge shows a seam where the footage ends and the page begins. Here
the letterbox bars are *the same black as the page*, so they are invisible, and you keep the
composition the generator actually made instead of throwing 10–15 % of it away. On the build
this skill was written from, `cover` cropped the sides and pushed the object hard into the
left of the fold; `contain` put it back where it was framed.

**Then zoom on portrait.** `contain` on a phone fits a 16:9 frame into a tall canvas as a
thin band across the middle — the object comes out tiny with vast emptiness above and below.
`zoom: 1.75` restores its size by cropping the sides, where there is nothing but void anyway.
Gate the switch on **aspect ratio**, not width: a tablet held upright has the same problem.

**Run it forward and back.** `pingpong: true` appends the reversed frame list, so the object
takes itself apart and then puts itself together again. The scenario doubles in length for
**zero extra credits**, and the turn cannot show a seam because it is literally the same
frames in reverse. A one-way explosion ends on a pile of parts, which is an odd note to leave
a product page on; ending back on the assembled object is the better story anyway.

**One hold, at the peak.** With ping-pong you now *do* want a `timeline` — a single dwell on
the fully exploded state, and nothing else:

```js
timeline: [
  { to: 0.50, scroll: 5 },     // разбирается
  { to: 0.52, scroll: 2.5 },   // держим на разобранном
  { to: 1.00, scroll: 4 },     // собирается
]
```

Travel 9 against hold 2.5. Weighting it the other way is the first thing a client calls
sticky — that lesson is from the walk and it transfers exactly.

Section height at **9–10 px of scroll per frame**, as always: 240 frames on an 833 px
viewport is about 4 screens. Shorter than a walk, and that is correct — one gesture should
not take fifteen screens to complete.

Page ground must be the same black as the frames, or the edge comes back.

### 6a · Put the words inside the sequence, not under it

This is the difference between a page and a video with captions, and it was the single
loudest piece of feedback on the reference build: *«не видно, что это вообще сайт, как будто
просто видео какое-то»*.

**Bind each block of copy to the frames where its part actually separates.** Nine parts, nine
bands of scroll. The reader sees the crystal lift and reads about the crystal in the same
moment; a list of the same nine paragraphs *below* the hero asks them to remember what they
saw and match it up themselves, and they won't.

```html
<article class="note" data-from="0.150" data-to="0.195" data-at="top">…</article>
```

Read the bounds off the markup rather than keeping a separate schedule in JS — a schedule
that lives away from the text drifts out of sync with it the first time either changes.

**Set the type large.** Part name at 44–48 px, body at 19–21 px. Annotation-sized type is
what makes a scroll hero read as subtitles. If the copy is worth showing it is worth setting.

**Then make room for it, with numbers.** The generated object almost never leaves a usable
column. Measure the object's extreme edge across *every* frame, not a sample:

- On the reference build the object reached **80.5 % of the frame width** at full explosion
  (the strap buckle), while a 26 rem right-hand column starts at 65 %.
- `offsetX: -0.19` moved the object to 2 %–61.5 % and left a 25 px gap at the narrowest
  desktop, growing with width. On black the shift costs nothing — what moves is void.

**And know when the column stops fitting.** Below about 1216 px there is no room for two
columns: the copy goes to a band at the bottom over a gradient, and the frame lifts
(`offsetY: -0.11`) so the object doesn't sit under it. Three modes, chosen by aspect and
width — wide landscape, narrow landscape, portrait.

**Statements go in the column too.** A large line centred over the frame lands on the object,
because with `contain` the object occupies nearly the full stage height. Do not reach for a
scrim to fix that: darkening the frame under text is the other thing clients reject on sight.

### 7 · The rest of the page

**Break the ground exactly once.** After the hero, one section on light paper. Nothing else
signals *this is a website, not a film* as cheaply or as clearly, and it gives the spec table
somewhere to live that isn't more small text on black. Then return to black to close.

The sections that suit this shape, in order:

- **Overlay on the hero** — a small label, one display line, one sentence, one button. Sitting
  over a bottom gradient so it reads at any frame. Nothing else.
- **Features** — what the parts you just watched separate actually do. The exploded view has
  earned the reader's attention on components; spend it. Real copy, no lorem.
- **Specifications** — a two-column table. This is where an exploded hero pays off: the reader
  has just seen the anatomy, so the numbers land.
- **Closing CTA** — one line, one button.

Use `useInView`-style fade-ins if the project has a motion library; plain
`IntersectionObserver` with an opacity and 24 px rise otherwise. One entrance pattern for the
whole page, not one per section.

---

## Verify before handing back

- **Frames differ across scroll.** Hash the canvas at ~20 positions; all should differ.
- **No stall.** No two adjacent samples identical — that means a frame never loaded.
- **Px per frame** between 9 and 10.
- **The background is the same black** in the frames and in the page. Sample a corner pixel of
  the canvas and compare with the computed page background; they should match within a point
  or two. If the frames are `#0a0a0a` and the page is `#000`, the edge shows on a good screen.
- **No horizontal scroll** at 320 / 375 / 414 / 768 px.
- **`brightness_curve` drift** under about ±6 across the take.

---

## Honesty

An exploded view is a legitimate and old convention in product marketing — nobody believes a
watch really floats apart. That is not the risk here.

The risk is the **object itself**. If the product is real and someone can buy it, the base
image must be the client's own photograph. Generating a plausible-looking version of a real
product and exploding that is misrepresentation: the proportions, the finish, the component
count will all be subtly wrong, and the page is making a claim about a thing that exists.

- **Client's product, client's photograph.** Generate the explosion from it, never the product.
- **No third-party brands.** Do not generate a recognisable Rolex, Dyson, or anything else the
  client does not own, even as a demo.
- **No fabricated specifications.** The specs table is where an exploded hero tempts you to
  invent a movement type or a power reserve. Every number comes from the client.
- **Regulated products** — medicines, supplements, cosmetics with active claims, anything with
  a dosage — get the hero and nothing else. Composition and effect claims come from their own
  approved material.

If the client has no photograph and wants the object generated anyway, build it and say once,
plainly, in the handover: the object shown is a representation, not their product.
