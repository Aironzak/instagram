/**
 * Скролл-промотка последовательности кадров на <canvas>.
 *
 *   const seq = new ScrollFrames({
 *     canvas: document.querySelector('#hero'),
 *     scroller: document.querySelector('.hero-section'),
 *     dir: './frames',
 *     manifest: './frames/manifest.json',
 *   });
 *   seq.start();
 *
 * Почему canvas, а не <img src>: смена src запускает декод и перерисовку,
 * из-за чего на промотке видно мигание. Здесь все кадры декодированы заранее
 * и лежат в памяти, а drawImage только копирует пиксели.
 */
/**
 * Пока страница не разложена — а в скрытой вкладке это надолго — innerWidth
 * равен нулю, и любой запрос вида (max-width: …) отвечает «да». Движок из-за
 * этого решал, что он на телефоне, брал каждый второй кадр и промотка шла
 * вдвое быстрее задуманного. Ждать раскладку нельзя: rAF в скрытой вкладке не
 * вызывается, и ожидание повисает навсегда. Поэтому неизвестную ширину считаем
 * не телефоном, а неизвестностью, и по умолчанию идём полным набором кадров.
 */
function isNarrow(query) {
  return window.innerWidth > 0 && window.matchMedia(query).matches;
}

export default class ScrollFrames {
  constructor({
    canvas,
    scroller,
    dir,
    manifest,
    // На телефоне столько кадров не нужно — там и экран меньше, и трафик дороже.
    mobileStride = 2,
    mobileQuery = '(max-width: 768px)',
    // Ритм промотки. Каждый отрезок: `to` — до какой доли кадров доехать,
    // `scroll` — сколько долей скролла на это потратить. Много скролла на малый
    // кусок кадров = камера ползёт; мало скролла на большой кусок = рывок вперёд.
    // Так пауза у предмета и быстрый переезд к следующему настраиваются здесь,
    // а не пересъёмкой видео. null = равномерно.
    //
    //   timeline: [
    //     { to: 0.30, scroll: 1 },   // подъезд к столу
    //     { to: 0.34, scroll: 3 },   // стоим у стола
    //     { to: 0.62, scroll: 1 },   // переезд к окну
    //     { to: 0.66, scroll: 3 },   // стоим у окна
    //     { to: 1.00, scroll: 1 },   // уход к шкафу
    //   ]
    timeline = null,
    // Сглаживание внутри отрезка, чтобы переезды не дёргались на стыках.
    ease = true,
    // Как кадр ложится в холст.
    //   'cover'   — заполнить целиком, лишнее срезать. Для интерьеров: там
    //               важно, чтобы кадр упирался в края, иначе виден шов страницы.
    //   'contain' — вписать целиком, добавив поля. На чёрной подложке поля
    //               того же цвета, что и фон кадра, поэтому их не видно — зато
    //               композиция, которую сделал генератор, доходит до зрителя
    //               неурезанной. Для предмета в пустоте это правильный режим.
    fit = 'cover',
    // Множитель к посчитанному масштабу. Нужен на портретном экране: кадр 16:9,
    // вписанный по contain в вертикальный холст, превращается в узкую полоску,
    // и предмет выходит мелким. zoom 1.6–1.8 возвращает ему размер, срезая по
    // бокам пустоту, которой там всё равно ничего нет. Меняется на лету:
    //   seq.zoom = 1.7; seq.redraw();
    zoom = 1,
    // Прогнать набор вперёд, а затем назад. Предмет разбирается и собирается
    // обратно — сценарий вдвое длиннее, кредитов ноль, швов не бывает в
    // принципе: это буквально те же кадры в обратном порядке.
    pingpong = false,
    // Сдвиг кадра внутри холста, в долях его ширины и высоты. Генератор почти
    // никогда не ставит предмет туда, где он нужен вёрстке. На чёрной подложке
    // сдвиг бесплатен: едет пустота, а предмет освобождает колонку под текст.
    //   offsetX: -0.1  — кадр уезжает влево на десятую часть ширины холста.
    offsetX = 0,
    offsetY = 0,
    // Вызывается после каждой перерисовки: (доля отснятого 0..1, номер слота).
    // Через неё вешаются подписи, привязанные к остановкам камеры.
    onFrame = null,
  }) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d', { alpha: false });
    this.scroller = scroller || canvas.parentElement;
    this.dir = dir.replace(/\/$/, '');
    this.manifestURL = manifest;
    this.mobileStride = mobileStride;
    this.mobileQuery = mobileQuery;
    this.ease = ease;
    this.fit = fit;
    this.zoom = zoom;
    this.pingpong = pingpong;
    this.offsetX = offsetX;
    this.offsetY = offsetY;
    this.onFrame = onFrame;
    this.segments = timeline ? this.buildTimeline(timeline) : null;

    // Цвет полей берём с самой страницы, чтобы он совпал с фоном точно, а не
    // «примерно чёрный» — на хорошем экране разница в один пункт уже видна.
    this.padColor = getComputedStyle(canvas).backgroundColor || '#000';

    this.images = [];
    this.indices = [];
    this.current = -1;
    this.drawn = -1;
    this.ready = false;
    this.raf = 0;
    this.reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    this.onScroll = this.onScroll.bind(this);
    this.onResize = this.onResize.bind(this);
  }

  async start() {
    const res = await fetch(this.manifestURL);
    if (!res.ok) throw new Error(`манифест не загрузился: ${res.status}`);
    this.meta = await res.json();

    const total = this.meta.frames;
    const stride = isNarrow(this.mobileQuery) ? this.mobileStride : 1;
    this.indices = [];
    for (let i = 0; i < total; i += stride) this.indices.push(i);
    // Последний кадр должен попасть в набор при любом шаге, иначе анимация
    // не доигрывает до конца и обрывается на середине движения.
    if (this.indices[this.indices.length - 1] !== total - 1) this.indices.push(total - 1);

    if (this.pingpong) {
      // Обратный ход без повтора крайнего кадра: иначе на развороте предмет
      // на один слот замирает, и это читается как подвисание.
      const back = this.indices.slice(0, -1).reverse();
      this.forwardCount = this.indices.length;
      this.indices = this.indices.concat(back);
    } else {
      this.forwardCount = this.indices.length;
    }

    this.resizeCanvas();

    // Первый кадр рисуем сразу, остальные догружаем в фоне: секция не должна
    // висеть пустой, пока едет вся последовательность.
    await this.load(0);
    this.draw(0);

    if (this.reduced) return; // статичный кадр — и всё

    window.addEventListener('scroll', this.onScroll, { passive: true });
    window.addEventListener('resize', this.onResize, { passive: true });

    this.preloadRest();
  }

  frameURL(i) {
    const pattern = this.meta.pattern || 'frame_%04d.jpg';
    const name = pattern.replace(/%0(\d+)d/, (_, w) => String(i).padStart(+w, '0'));
    return `${this.dir}/${name}`;
  }

  load(slot) {
    if (this.images[slot]) return Promise.resolve(this.images[slot]);
    return new Promise((resolve) => {
      const img = new Image();
      img.decoding = 'async';
      img.onload = () => { this.images[slot] = img; resolve(img); };
      img.onerror = () => resolve(null);
      img.src = this.frameURL(this.indices[slot]);
    });
  }

  async preloadRest() {
    // Грузим в несколько проходов: сперва каждый восьмой кадр по всей длине,
    // потом сгущаем. Так весь проход становится проматываемым через пару секунд —
    // грубо, но без замираний, — а не через минуту и подряд от начала.
    const total = this.indices.length;
    for (const step of [8, 4, 2, 1]) {
      const queue = [];
      for (let s = 0; s < total; s += step) if (!this.images[s]) queue.push(s);
      // Пачками, а не по одному: сотня последовательных запросов — это сотня
      // круговых задержек, и первые секунды прокрутки приходятся ровно на них.
      const LANES = 8;
      for (let i = 0; i < queue.length; i += LANES) {
        await Promise.all(queue.slice(i, i + LANES).map((slot) => this.load(slot)));
        if (this.current >= 0) this.draw(this.current);
      }
      if (step === 1) this.ready = true;
    }
  }

  /** Ближайший загруженный слот — чтобы промотка не застревала на дырах. */
  nearestLoaded(slot) {
    if (this.images[slot]) return slot;
    for (let d = 1; d < this.indices.length; d++) {
      if (this.images[slot - d]) return slot - d;
      if (this.images[slot + d]) return slot + d;
    }
    return -1;
  }

  resizeCanvas() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const rect = this.canvas.getBoundingClientRect();
    this.canvas.width = Math.round(rect.width * dpr);
    this.canvas.height = Math.round(rect.height * dpr);
  }

  draw(slot) {
    const use = this.nearestLoaded(slot);
    if (use < 0) return;
    const img = this.images[use];

    const { width: cw, height: ch } = this.canvas;
    const sx = cw / img.naturalWidth;
    const sy = ch / img.naturalHeight;
    const base = this.fit === 'contain' ? Math.min(sx, sy) : Math.max(sx, sy);
    const scale = base * this.zoom;
    const w = img.naturalWidth * scale;
    const h = img.naturalHeight * scale;
    if (this.fit === 'contain' || this.zoom < 1 || this.offsetX || this.offsetY) {
      // Поля надо закрашивать: без этого на них остаётся предыдущий кадр.
      this.ctx.fillStyle = this.padColor;
      this.ctx.fillRect(0, 0, cw, ch);
    }
    this.ctx.drawImage(
      img,
      (cw - w) / 2 + cw * this.offsetX,
      (ch - h) / 2 + ch * this.offsetY,
      w,
      h,
    );
    // Помним запрошенный слот, а не подставленный: когда настоящий кадр
    // догрузится, перерисовка произойдёт сама.
    this.current = slot;
    this.drawn = use;
    if (this.onFrame) {
      const last = this.indices.length - 1;
      this.onFrame(last > 0 ? slot / last : 0, slot);
    }
  }

  /**
   * Разворачивает timeline в отрезки с накопленными границами по скроллу и по кадрам.
   * Доли scroll нормируются, так что писать можно любые числа — важно их соотношение.
   */
  buildTimeline(timeline) {
    const total = timeline.reduce((s, seg) => s + (seg.scroll ?? 1), 0);
    if (!(total > 0)) throw new Error('timeline: сумма scroll должна быть больше нуля');

    const segments = [];
    let scrollAt = 0;
    let frameAt = 0;
    for (const seg of timeline) {
      const share = (seg.scroll ?? 1) / total;
      const to = Math.min(1, Math.max(0, seg.to));
      // Кадры не должны идти назад — иначе камера дёрнется в обратную сторону.
      if (to < frameAt) throw new Error(`timeline: to=${seg.to} меньше предыдущего ${frameAt}`);
      segments.push({ s0: scrollAt, s1: scrollAt + share, f0: frameAt, f1: to });
      scrollAt += share;
      frameAt = to;
    }
    // Хвост округления добиваем до единицы, чтобы последний кадр был достижим.
    segments[segments.length - 1].s1 = 1;
    segments[segments.length - 1].f1 = 1;
    return segments;
  }

  /** Доля скролла -> доля отснятого материала. */
  curve(p) {
    if (!this.segments) return p;
    const seg = this.segments.find((s) => p <= s.s1) ?? this.segments[this.segments.length - 1];
    const span = seg.s1 - seg.s0;
    let t = span > 0 ? (p - seg.s0) / span : 1;
    t = Math.min(1, Math.max(0, t));
    if (this.ease) t = t * t * (3 - 2 * t); // smoothstep
    return seg.f0 + (seg.f1 - seg.f0) * t;
  }

  progress() {
    const rect = this.scroller.getBoundingClientRect();
    const travel = rect.height - window.innerHeight;
    if (travel <= 0) return 0;
    return Math.min(1, Math.max(0, -rect.top / travel));
  }

  onScroll() {
    if (this.raf) return; // один расчёт на кадр экрана, а не на каждое событие
    this.raf = requestAnimationFrame(() => {
      this.raf = 0;
      const slot = Math.min(
        this.indices.length - 1,
        Math.round(this.curve(this.progress()) * (this.indices.length - 1)),
      );
      if (slot !== this.current || this.drawn !== this.nearestLoaded(slot)) this.draw(slot);
    });
  }

  onResize() {
    this.resizeCanvas();
    this.redraw();
  }

  /** Перерисовать текущий кадр — после смены fit или zoom. */
  redraw() {
    if (this.current >= 0) this.draw(this.current);
  }

  destroy() {
    window.removeEventListener('scroll', this.onScroll);
    window.removeEventListener('resize', this.onResize);
    if (this.raf) cancelAnimationFrame(this.raf);
    this.images = [];
  }
}
