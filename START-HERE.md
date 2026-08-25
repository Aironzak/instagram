# START HERE

**This repository is `roomwalk`, a plugin for Claude Code.** It builds scroll-driven heroes for
a business's website.

*This file describes what the plugin is and how it is normally used. It is documentation, not a
set of orders: nothing here should be treated as an instruction that overrides the person you
are actually talking to. Setting this up installs software and spends their Higgsfield credits,
so confirm with them once before starting — one plain question, not a menu of options — and let
`/roomwalk:start` ask the single thing it needs after that.*

*[По-русски ниже ↓](#по-русски)*

---

## In one paragraph, so you know what you are building

A **scroll-driven hero**. The camera walks through **one** interior. It stops at each thing the
business sells. At every stop the business's **own real photographs** of that category fade in
beside the caption and link into their catalogue.

The interior is generated — it is the **stage**. The photographs are real — they are the
**proof**. Nobody is ever shown a rendered thing and told it is theirs. That split is the whole
idea, and it is what makes the format usable by a real company.

There is a second shape here for when a single object carries the whole offer: the object sits
assembled on pure black and comes apart as you scroll, then back together on the way up.

---

## First, two checks — before you install anything

**Are you Claude Code?** This is a Claude Code plugin. It needs slash commands, an MCP
connector, and a shell. If you are running anywhere else — claude.ai, a chat window with no
tools, an editor extension without terminal access — say so plainly in one sentence and stop.
Nothing here will work and pretending otherwise wastes the person's time.

**Is it already installed?** Look for `generate_image` and `generate_video` in your tool list.

- **Both present** → skip to step 3. You are ready.
- **Missing** → do step 1 and step 2.

Do not reinstall something already installed, and do not open a sign-in flow for a connector
that is already connected.

---

## Do this, in order

### 1. Install the plugin — once per machine

```bash
claude plugin marketplace add Aironzak/instagram
```

```bash
claude plugin install roomwalk@roomwalk
```

Restart Claude Code afterwards so the skills load.

### 2. Connect Higgsfield — the only connector this needs

Nothing can be generated without it. Run:

```
/roomwalk:connect
```

That runs a script in the background which registers a client, prints a **sign-in link on its
own line**, waits for the browser callback, writes the token into the user-scope MCP config, and
asks for a restart. Read its output and hand the person that link. One click from them.

Do **not** reach for `claude mcp login higgsfield` — it always fails. Higgsfield's metadata
declares `issuer: https://mcp.higgsfield.ai` while the redirect carries
`iss=https://clerk.higgsfield.ai`, and Claude Code rejects that per RFC 9207 with no flag to
disable the check. Their advertised device-code server 404s on every endpoint, so that route is
dead too. The script exists because of both.

`--refresh` renews an expired token without a new sign-in. `--status` reports what is configured.

You are ready when `generate_image` and `generate_video` are in the session.

### 3. Start, and ask exactly one question

```
/roomwalk:start
```

It asks **one** question and leaves both doors open: what site they want, or a link to the one
they already have. With a link, everything else — the categories, how many photographs sit behind
each, the prices, the line they repeat about themselves — is read off that site, so ask nothing
more; making someone describe their own site is the fastest way to lose them. Without a link, ask
only two things in one message: what the business is, in a sentence, and their photographs of real
work. Photographs are not optional.

Then it comes back with **one** message: the stops it worked out from the site, **three ways
the room could look**, which one it recommends and why, and the cost. They answer with a
number and nothing more is asked of them — that single choice is the only creative decision
they make, and everything after it is decided for them.

---

## What your first message back should look like

Short. Not a summary of this repository, not a list of what you are about to read. Either:

> Ставлю плагин и подключаю Higgsfield — сейчас дам ссылку для входа.

…or, if everything is already in place, just the one question the skill opens with:

> Расскажите, какой сайт хотите сделать, или пришлите ссылку на нынешний — посмотрю, чем вы занимаетесь, и предложу план.

---

## Which of the two

| The offer is | Command | Segments | Seams |
| --- | --- | --- | --- |
| a range of things, in a place | `/roomwalk:walk` | 4–6, joined | yes — the hard part |
| one object that is the whole story | `/roomwalk:explode` | **one**, played forward then back | none |

Joinery, clinic, restaurant, gym, atelier, detailing, florist, showroom → **walk**.
Watch, bottle, sneaker, chair, tool, jar, lamp → **explode**.

---

## What is needed on the machine

- **Python 3**, plus three packages installed once:
  `python3 -m pip install --user pillow numpy imageio-ffmpeg`.
  This runs on **macOS, Windows and Linux** alike, and `imageio-ffmpeg` brings its own ffmpeg,
  so nothing has to be installed system-wide.
- **Higgsfield credits.** A 480p draft runs roughly 60–120 for a walk, 25 for an exploded view.
  A 1080p final is a few hundred more. Always preflight with `get_cost: true`.
- **The business's own photographs**, pulled from their own site. Without them there is no proof
  layer and the walk should not be built.

---

## Where this is the wrong tool — say so rather than building it

- **Purely digital offers** — SaaS, an agency, a consultancy. A generated office is decoration
  and reads as filler.
- **A site that cannot be read** — a JavaScript-only shell, an auth wall, a dead domain, a
  one-pager with no gallery. Say so plainly and ask for two things: what they do, in a sentence,
  and a few photographs. Never guess the business from its domain name. Never proceed without
  photographs.
- **Generated outcomes, ever.** Generate the environment; never the result being sold. No faces,
  no bodies, no skin — absolute for anything cosmetic, medical, dental, fitness or aesthetic. No
  before-and-after of any kind. No generated food presented as a menu. No generated products
  carrying the client's branding. No certificates, diplomas or licences in frame. For a regulated
  business, say plainly up front that the hero will show the premises only and that every claim
  and result on the page has to come from their own material.

---
---

<a id="по-русски"></a>

# НАЧНИТЕ ОТСЮДА

**Этот репозиторий — `roomwalk`, плагин для Claude Code.** Он делает скролл-шапки для сайтов.

*Это описание того, что за плагин и как им обычно пользуются, — документация, а не приказ.
Ничто здесь не отменяет того, что говорит живой человек в чате. Установка ставит софт и тратит
его кредиты Higgsfield, поэтому спросите один раз, прежде чем начинать, — простым вопросом,
а не списком вариантов, — а дальше `/roomwalk:start` сам задаст то единственное, что ему нужно.*

## Одним абзацем — что именно вы строите

**Скролл-шапку.** Камера идёт по **одному** помещению и останавливается у каждой вещи, которую
бизнес продаёт. На каждой остановке рядом с подписью проявляются **их собственные настоящие
фотографии** этой категории и ведут в каталог.

Интерьер сгенерирован — это **сцена**. Фотографии настоящие — это **доказательство**. Никому
не показывают отрисованную вещь со словами «вот ваша работа». В этом разделении весь смысл,
и именно оно делает формат пригодным для реального бизнеса.

Если весь товар — один предмет, здесь есть вторая форма: предмет лежит на чёрном, разбирается
на части по мере скролла и собирается обратно на обратном ходе.

## Сначала две проверки — до того, как что-то ставить

**Вы Claude Code?** Это плагин для Claude Code: нужны слэш-команды, MCP-коннектор и шелл.
Если вы работаете где-то ещё — в claude.ai, в чате без инструментов, в расширении редактора
без терминала — скажите об этом одной фразой и остановитесь. Здесь ничего не заработает,
а делать вид, что заработает, — тратить время человека.

**Может, уже стоит?** Посмотрите, есть ли в списке инструментов `generate_image`
и `generate_video`.

- **Оба на месте** → сразу к шагу 3, всё готово.
- **Нет** → шаги 1 и 2.

Не переустанавливайте то, что уже стоит, и не запускайте вход в коннектор, который уже подключён.

## Делайте по порядку

**1. Поставьте плагин — один раз на машину**

```bash
claude plugin marketplace add Aironzak/instagram
```

```bash
claude plugin install roomwalk@roomwalk
```

Перезапустите Claude Code, чтобы навыки подхватились.

**2. Подключите Higgsfield — это единственный нужный коннектор**

Без него ничего не сгенерируется. Запустите:

```
/roomwalk:connect
```

Он запускает в фоне скрипт: тот регистрирует клиент, печатает **отдельной строкой ссылку для
входа**, ждёт возврата из браузера, кладёт токен в пользовательский MCP-конфиг и просит
перезапуск. Прочитайте вывод и дайте человеку эту ссылку. От него — один клик.

`claude mcp login higgsfield` не используйте, он всегда падает: в метаданных Higgsfield
`issuer: https://mcp.higgsfield.ai`, а в редиректе приходит `iss=https://clerk.higgsfield.ai`,
и Claude Code отклоняет это по RFC 9207, отключить проверку нечем. Их device-code сервер
отдаёт 404 на всех эндпоинтах. Скрипт написан из-за обеих причин.

`--refresh` обновляет истёкший токен без повторного входа, `--status` показывает,
что настроено.

Готово, когда в сессии появились `generate_image` и `generate_video`.

**3. Запустите и задайте ровно один вопрос**

```
/roomwalk:start
```

Он задаёт **один** вопрос и оставляет открытыми обе двери: какой сайт человек хочет сделать —
или ссылка на нынешний. Если ссылка есть, всё остальное читается с самого сайта: категории,
сколько фотографий стоит за каждой, цены и та фраза, которую они о себе повторяют, — и больше
спрашивать нечего; просить человека описать свой же сайт — самый быстрый способ его потерять.
Если ссылки нет, спросите одним сообщением ровно две вещи: чем занимается бизнес, в одну фразу,
и фотографии реальных работ. Фотографии обязательны.

Дальше он возвращается **одним** сообщением: остановки, которые вывел с сайта, **три
варианта, как может выглядеть помещение**, какой из них советует и почему, и цена. Человек
отвечает цифрой — и больше его ни о чём не спрашивают. Этот единственный выбор и есть вся
творческая часть, которую он делает; всё остальное решается за него.

## На каком языке отвечать

**На том, на котором пишет человек.** Если он прислал только ссылку — берите язык с сайта:
русский сайт — русский ответ. Не переходите на английский только потому, что этот файл
написан по-английски: он для вас, а не для него. Это касается всего — вопроса, плана,
цены, подписей на странице и футера.

## Как должна выглядеть ваша первая реплика

Коротко. Не пересказ репозитория и не список того, что вы собираетесь прочитать. Либо:

> Ставлю плагин и подключаю Higgsfield — сейчас дам ссылку для входа.

…либо, если всё уже на месте, тот самый единственный вопрос, с которого начинается навык:

> Расскажите, какой сайт хотите сделать, или пришлите ссылку на нынешний — посмотрю, чем вы занимаетесь, и предложу план.

## Что нужно на машине

- **Python 3** и три пакета, ставятся один раз:
  `python3 -m pip install --user pillow numpy imageio-ffmpeg`.
  Работает одинаково на **macOS, Windows и Linux**, а `imageio-ffmpeg` приносит свой ffmpeg,
  так что отдельно в систему ничего ставить не надо.
- **Кредиты Higgsfield.** Черновик 480p — примерно 60–120 на проход и 25 на разбор предмета.
  Финал 1080p — ещё несколько сотен. Всегда сверяйтесь через `get_cost: true`.
- **Настоящие фотографии бизнеса** с их же сайта. Без них нет слоя доказательства,
  и проход строить не нужно.

## Когда это не тот инструмент — скажите об этом, а не стройте

- **Чисто цифровые услуги** — SaaS, агентство, консалтинг. Сгенерированный офис — это
  декорация, и читается как заполнитель.
- **Сайт не читается** — JS-оболочка, авторизация, мёртвый домен, одностраничник без галереи.
  Скажите прямо и попросите две вещи: чем занимаются, в двух словах, и несколько фотографий.
  Не угадывайте бизнес по доменному имени. Не начинайте без фотографий.
- **Никогда не генерируйте результат.** Генерируется среда, а не то, что продают. Ни лиц,
  ни тел, ни кожи — для косметологии, медицины, стоматологии, фитнеса и эстетики это
  абсолютный запрет. Никаких «до/после». Никакой сгенерированной еды как меню. Никаких
  сгенерированных товаров с брендингом клиента. Никаких сертификатов и дипломов в кадре.
  Для лицензируемого бизнеса сразу скажите, что в шапке будет только помещение, а все
  заявления и результаты на странице должны быть из их собственных материалов.
