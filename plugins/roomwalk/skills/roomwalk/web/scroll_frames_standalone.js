/* Промотка кадров скроллом на <canvas>.
 *
 * Это не модуль. Файл открывается с диска (file://), где ES-модули и fetch
 * запрещены политикой источника, поэтому: обычный скрипт, манифест вписан
 * в страницу, кадры грузятся через Image() по относительному пути — это
 * единственный способ достучаться до соседней папки с диска.
 */
(function (global) {
  'use strict';

  function isNarrow(query) {
    // До раскладки innerWidth равен нулю, и любой (max-width: …) отвечает «да».
    // Неизвестную ширину считаем неизвестностью, а не телефоном.
    return global.innerWidth > 0 && global.matchMedia(query).matches;
  }

  function ScrollFrames(opts) {
    this.canvas = opts.canvas;
    this.ctx = this.canvas.getContext('2d', { alpha: false });
    this.scroller = opts.scroller || this.canvas.parentElement;
    this.dir = String(opts.dir).replace(/\/$/, '');
    this.meta = opts.meta;                       // манифест вписан, не запрашивается
    this.mobileStride = opts.mobileStride || 2;
    this.mobileQuery = opts.mobileQuery || '(max-width: 768px)';
    this.fit = opts.fit || 'cover';
    this.zoom = opts.zoom || 1;
    this.offsetX = opts.offsetX || 0;
    this.offsetY = opts.offsetY || 0;
    this.pingpong = !!opts.pingpong;
    this.ease = opts.ease !== false;
    this.onFrame = opts.onFrame || null;
    this.segments = opts.timeline ? this.buildTimeline(opts.timeline) : null;

    // Цвет полей берём со страницы, чтобы совпал точно, а не «примерно».
    this.padColor = global.getComputedStyle(this.canvas).backgroundColor || '#fff';

    this.images = [];
    this.indices = [];
    this.current = -1;
    this.drawn = -1;
    this.raf = 0;
    this.reduced = global.matchMedia('(prefers-reduced-motion: reduce)').matches;

    this.onScroll = this.onScroll.bind(this);
    this.onResize = this.onResize.bind(this);
  }

  ScrollFrames.prototype.start = function () {
    var total = this.meta.frames;
    var stride = isNarrow(this.mobileQuery) ? this.mobileStride : 1;
    this.indices = [];
    for (var i = 0; i < total; i += stride) this.indices.push(i);
    if (this.indices[this.indices.length - 1] !== total - 1) this.indices.push(total - 1);

    if (this.pingpong) {
      // Крайний кадр не повторяем: на развороте он замер бы на лишний слот.
      this.forwardCount = this.indices.length;
      this.indices = this.indices.concat(this.indices.slice(0, -1).reverse());
    } else {
      this.forwardCount = this.indices.length;
    }

    this.resizeCanvas();

    var self = this;
    this.load(0, function () { self.draw(0); });

    if (this.reduced) return;

    global.addEventListener('scroll', this.onScroll, { passive: true });
    global.addEventListener('resize', this.onResize, { passive: true });
    this.preloadRest();
  };

  ScrollFrames.prototype.frameURL = function (i) {
    var pattern = this.meta.pattern || 'frame_%04d.jpg';
    return this.dir + '/' + pattern.replace(/%0(\d+)d/, function (_, w) {
      var s = String(i);
      while (s.length < +w) s = '0' + s;
      return s;
    });
  };

  ScrollFrames.prototype.load = function (slot, done) {
    var self = this;
    if (this.images[slot]) { if (done) done(this.images[slot]); return; }
    var img = new Image();
    img.decoding = 'async';
    img.onload = function () { self.images[slot] = img; if (done) done(img); };
    img.onerror = function () { if (done) done(null); };
    img.src = this.frameURL(this.indices[slot]);
  };

  ScrollFrames.prototype.preloadRest = function () {
    // Сперва каждый восьмой по всей длине, потом гуще. Последовательная загрузка
    // означала бы, что первую минуту скролл попадает в неприехавшие кадры.
    var self = this;
    var steps = [8, 4, 2, 1];
    var si = 0;

    function pass() {
      if (si >= steps.length) return;
      var step = steps[si++];
      var queue = [];
      for (var s = 0; s < self.indices.length; s += step) if (!self.images[s]) queue.push(s);
      var at = 0;
      var LANES = 8;

      function chunk() {
        if (at >= queue.length) { pass(); return; }
        var batch = queue.slice(at, at + LANES);
        at += LANES;
        var left = batch.length;
        batch.forEach(function (slot) {
          self.load(slot, function () {
            if (--left === 0) {
              if (self.current >= 0) self.draw(self.current);
              chunk();
            }
          });
        });
      }
      chunk();
    }
    pass();
  };

  /** Ближайший загруженный слот — чтобы промотка не застревала на дырах. */
  ScrollFrames.prototype.nearestLoaded = function (slot) {
    if (this.images[slot]) return slot;
    for (var d = 1; d < this.indices.length; d++) {
      if (this.images[slot - d]) return slot - d;
      if (this.images[slot + d]) return slot + d;
    }
    return -1;
  };

  ScrollFrames.prototype.resizeCanvas = function () {
    var dpr = Math.min(global.devicePixelRatio || 1, 2);
    var rect = this.canvas.getBoundingClientRect();
    this.canvas.width = Math.round(rect.width * dpr);
    this.canvas.height = Math.round(rect.height * dpr);
  };

  ScrollFrames.prototype.draw = function (slot) {
    var use = this.nearestLoaded(slot);
    if (use < 0) return;
    var img = this.images[use];
    var cw = this.canvas.width, ch = this.canvas.height;
    var sx = cw / img.naturalWidth, sy = ch / img.naturalHeight;
    var base = this.fit === 'contain' ? Math.min(sx, sy) : Math.max(sx, sy);
    var scale = base * this.zoom;
    var w = img.naturalWidth * scale, h = img.naturalHeight * scale;

    if (this.fit === 'contain' || this.zoom < 1 || this.offsetX || this.offsetY) {
      this.ctx.fillStyle = this.padColor;
      this.ctx.fillRect(0, 0, cw, ch);
    }
    /* Перекрытие в два пикселя: на самом краю картинки JPEG оставляет светлую
       кромку в 2–4 пункта, и на ровной подложке она читается тонкой линией по
       периметру кадра. Одного пикселя не хватило — замерено на готовой
       странице. Рисуем чуть крупнее, чтобы кромка ушла за видимую область. */
    var bleed = this.fit === 'contain' ? 4 : 0;
    this.ctx.drawImage(img,
      (cw - w) / 2 + cw * this.offsetX - bleed,
      (ch - h) / 2 + ch * this.offsetY - bleed,
      w + bleed * 2, h + bleed * 2);

    this.current = slot;
    this.drawn = use;
    if (this.onFrame) {
      var last = this.indices.length - 1;
      this.onFrame(last > 0 ? slot / last : 0, slot);
    }
  };

  ScrollFrames.prototype.redraw = function () {
    if (this.current >= 0) this.draw(this.current);
  };

  ScrollFrames.prototype.buildTimeline = function (timeline) {
    var total = 0, i;
    for (i = 0; i < timeline.length; i++) total += (timeline[i].scroll == null ? 1 : timeline[i].scroll);
    if (!(total > 0)) throw new Error('timeline: сумма scroll должна быть больше нуля');
    var segments = [], scrollAt = 0, frameAt = 0;
    for (i = 0; i < timeline.length; i++) {
      var seg = timeline[i];
      var share = (seg.scroll == null ? 1 : seg.scroll) / total;
      var to = Math.min(1, Math.max(0, seg.to));
      if (to < frameAt) throw new Error('timeline: to меньше предыдущего');
      segments.push({ s0: scrollAt, s1: scrollAt + share, f0: frameAt, f1: to });
      scrollAt += share;
      frameAt = to;
    }
    segments[segments.length - 1].s1 = 1;
    segments[segments.length - 1].f1 = 1;
    return segments;
  };

  ScrollFrames.prototype.curve = function (p) {
    if (!this.segments) return p;
    var seg = null;
    for (var i = 0; i < this.segments.length; i++) {
      if (p <= this.segments[i].s1) { seg = this.segments[i]; break; }
    }
    if (!seg) seg = this.segments[this.segments.length - 1];
    var span = seg.s1 - seg.s0;
    var t = span > 0 ? (p - seg.s0) / span : 1;
    t = Math.min(1, Math.max(0, t));
    if (this.ease) t = t * t * (3 - 2 * t);
    return seg.f0 + (seg.f1 - seg.f0) * t;
  };

  ScrollFrames.prototype.progress = function () {
    var rect = this.scroller.getBoundingClientRect();
    var travel = rect.height - global.innerHeight;
    if (travel <= 0) return 0;
    return Math.min(1, Math.max(0, -rect.top / travel));
  };

  ScrollFrames.prototype.onScroll = function () {
    if (this.raf) return;
    var self = this;
    this.raf = requestAnimationFrame(function () {
      self.raf = 0;
      var last = self.indices.length - 1;
      var slot = Math.min(last, Math.round(self.curve(self.progress()) * last));
      if (slot !== self.current || self.drawn !== self.nearestLoaded(slot)) self.draw(slot);
    });
  };

  ScrollFrames.prototype.onResize = function () {
    this.resizeCanvas();
    this.redraw();
  };

  global.ScrollFrames = ScrollFrames;
}(window));
