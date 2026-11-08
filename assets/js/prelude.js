/* 爽听 MusicFree 插件运行时前置环境
 * 目标：在不改动插件源码的前提下，提供 CommonJS / 浏览器 / Node 的最小混合环境。
 * 只实现插件实际会用到的能力，保持小而可预测。
 */
(function () {
  var g = globalThis;
  g.global = g;
  g.window = g;
  g.self = g;

  // ---------- base64 ----------
  var B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  if (typeof g.btoa !== 'function') {
    g.btoa = function (input) {
      var str = String(input);
      var out = '';
      for (var i = 0; i < str.length; i += 3) {
        var c1 = str.charCodeAt(i);
        var c2 = str.charCodeAt(i + 1);
        var c3 = str.charCodeAt(i + 2);
        var e1 = c1 >> 2;
        var e2 = ((c1 & 3) << 4) | (isNaN(c2) ? 0 : c2 >> 4);
        var e3 = isNaN(c2) ? 64 : (((c2 & 15) << 2) | (isNaN(c3) ? 0 : c3 >> 6));
        var e4 = isNaN(c3) ? 64 : (c3 & 63);
        out += B64.charAt(e1) + B64.charAt(e2) + (e3 === 64 ? '=' : B64.charAt(e3)) + (e4 === 64 ? '=' : B64.charAt(e4));
      }
      return out;
    };
  }
  if (typeof g.atob !== 'function') {
    g.atob = function (input) {
      var str = String(input).replace(/[=]+$/, '');
      var out = '';
      var bc = 0, bs = 0;
      for (var i = 0; i < str.length; i++) {
        var c = B64.indexOf(str.charAt(i));
        if (c < 0) continue;
        bs = bc % 4 ? bs * 64 + c : c;
        if (bc++ % 4) out += String.fromCharCode(255 & (bs >> ((-2 * bc) & 6)));
      }
      return out;
    };
  }

  // ---------- UTF-8 ----------
  if (typeof g.TextEncoder !== 'function') {
    g.TextEncoder = function () {};
    g.TextEncoder.prototype.encode = function (str) {
      var bytes = [];
      for (var i = 0; i < str.length; i++) {
        var c = str.charCodeAt(i);
        if (c < 0x80) bytes.push(c);
        else if (c < 0x800) bytes.push(0xc0 | (c >> 6), 0x80 | (c & 63));
        else if (c >= 0xd800 && c <= 0xdbff && i + 1 < str.length) {
          var c2 = str.charCodeAt(++i);
          var cp = 0x10000 + ((c - 0xd800) << 10) + (c2 - 0xdc00);
          bytes.push(0xf0 | (cp >> 18), 0x80 | ((cp >> 12) & 63), 0x80 | ((cp >> 6) & 63), 0x80 | (cp & 63));
        } else bytes.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
      }
      return new Uint8Array(bytes);
    };
  }
  if (typeof g.TextDecoder !== 'function') {
    g.TextDecoder = function () {};
    g.TextDecoder.prototype.decode = function (buf) {
      var bytes = buf instanceof Uint8Array ? buf : new Uint8Array(buf || []);
      var out = '', i = 0;
      while (i < bytes.length) {
        var b = bytes[i++];
        if (b < 0x80) out += String.fromCharCode(b);
        else if (b < 0xe0) out += String.fromCharCode(((b & 31) << 6) | (bytes[i++] & 63));
        else if (b < 0xf0) out += String.fromCharCode(((b & 15) << 12) | ((bytes[i++] & 63) << 6) | (bytes[i++] & 63));
        else {
          var cp = ((b & 7) << 18) | ((bytes[i++] & 63) << 12) | ((bytes[i++] & 63) << 6) | (bytes[i++] & 63);
          cp -= 0x10000;
          out += String.fromCharCode(0xd800 + (cp >> 10), 0xdc00 + (cp & 1023));
        }
      }
      return out;
    };
  }

  // ---------- URLSearchParams / URL ----------
  function enc(s) {
    try { return encodeURIComponent(String(s)); } catch (e) { return String(s); }
  }
  function dec(s) {
    try { return decodeURIComponent(String(s).replace(/\+/g, ' ')); } catch (e) { return String(s); }
  }
  if (typeof g.URLSearchParams !== 'function') {
    g.URLSearchParams = function (init) {
      this._pairs = [];
      if (typeof init === 'string') {
        var q = init.charAt(0) === '?' ? init.slice(1) : init;
        if (q) q.split('&').forEach(function (kv) {
          if (!kv) return;
          var idx = kv.indexOf('=');
          this._pairs.push([dec(idx < 0 ? kv : kv.slice(0, idx)), idx < 0 ? '' : dec(kv.slice(idx + 1))]);
        }, this);
      } else if (init && typeof init === 'object') {
        Object.keys(init).forEach(function (k) {
          var v = init[k];
          if (Array.isArray(v)) v.forEach(function (x) { this._pairs.push([k, String(x)]); }, this);
          else this._pairs.push([k, String(v)]);
        }, this);
      }
    };
    g.URLSearchParams.prototype.append = function (k, v) { this._pairs.push([String(k), String(v)]); };
    g.URLSearchParams.prototype.set = function (k, v) {
      this.delete(k); this._pairs.push([String(k), String(v)]);
    };
    g.URLSearchParams.prototype.get = function (k) {
      for (var i = 0; i < this._pairs.length; i++) if (this._pairs[i][0] === k) return this._pairs[i][1];
      return null;
    };
    g.URLSearchParams.prototype.getAll = function (k) {
      return this._pairs.filter(function (p) { return p[0] === k; }).map(function (p) { return p[1]; });
    };
    g.URLSearchParams.prototype.has = function (k) { return this.get(k) !== null; };
    g.URLSearchParams.prototype['delete'] = function (k) {
      this._pairs = this._pairs.filter(function (p) { return p[0] !== k; });
    };
    g.URLSearchParams.prototype.toString = function () {
      return this._pairs.map(function (p) { return enc(p[0]) + '=' + enc(p[1]); }).join('&');
    };
    g.URLSearchParams.prototype.forEach = function (fn) {
      this._pairs.forEach(function (p) { fn(p[1], p[0], this); }, this);
    };
    g.URLSearchParams.prototype.keys = function () { return this._pairs.map(function (p) { return p[0]; })[Symbol.iterator](); };
    g.URLSearchParams.prototype.values = function () { return this._pairs.map(function (p) { return p[1]; })[Symbol.iterator](); };
    g.URLSearchParams.prototype.entries = function () { return this._pairs[Symbol.iterator](); };
  }
  if (typeof g.URL !== 'function') {
    g.URL = function (url, base) {
      var raw = String(url);
      var m = raw.match(/^([a-zA-Z][\w+.-]*:)\/\/([^/?#]*)([^?#]*)(\?[^#]*)?(#.*)?$/);
      if (!m && base) {
        var b = String(base).replace(/\/[^/]*$/, '/');
        m = (b + raw).match(/^([a-zA-Z][\w+.-]*:)\/\/([^/?#]*)([^?#]*)(\?[^#]*)?(#.*)?$/);
      }
      if (!m) throw new Error('Invalid URL: ' + raw);
      this.protocol = m[1];
      this.host = m[2];
      this.hostname = m[2].split(':')[0];
      this.port = m[2].split(':')[1] || '';
      this.pathname = m[3] || '/';
      this.search = m[4] || '';
      this.hash = m[5] || '';
      this.searchParams = new g.URLSearchParams(this.search);
      this.origin = this.protocol + '//' + this.host;
    };
    g.URL.prototype.toString = function () {
      var q = this.searchParams.toString();
      return this.protocol + '//' + this.host + this.pathname + (q ? '?' + q : '') + this.hash;
    };
    g.URL.prototype.toJSON = function () { return this.toString(); };
    g.URL.createObjectURL = function () { return ''; };
    g.URL.revokeObjectURL = function () {};
  }

  // ---------- Buffer (最小实现) ----------
  if (typeof g.Buffer !== 'function') {
    var BufferShim = function (bytes) {
      var arr = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes || []);
      arr.toString = function (encoding) {
        if (encoding === 'base64') {
          var s = '';
          for (var i = 0; i < arr.length; i++) s += String.fromCharCode(arr[i]);
          return g.btoa(s);
        }
        if (encoding === 'hex') {
          var h = '';
          for (var j = 0; j < arr.length; j++) h += ('0' + arr[j].toString(16)).slice(-2);
          return h;
        }
        try { return new g.TextDecoder().decode(arr); } catch (e) { return ''; }
      };
      return arr;
    };
    BufferShim.from = function (input, encoding) {
      if (typeof input === 'string') {
        if (encoding === 'base64') {
          var bin = g.atob(input);
          var out = new Uint8Array(bin.length);
          for (var i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
          return BufferShim(out);
        }
        if (encoding === 'hex') {
          var arr = [];
          for (var j = 0; j < input.length; j += 2) arr.push(parseInt(input.substr(j, 2), 16));
          return BufferShim(arr);
        }
        return BufferShim(new g.TextEncoder().encode(input));
      }
      if (input instanceof ArrayBuffer) return BufferShim(new Uint8Array(input));
      return BufferShim(input || []);
    };
    BufferShim.alloc = function (n) { return BufferShim(new Uint8Array(n)); };
    BufferShim.concat = function (list) {
      var total = 0;
      list.forEach(function (b) { total += b.length; });
      var out = new Uint8Array(total), off = 0;
      list.forEach(function (b) { out.set(b, off); off += b.length; });
      return BufferShim(out);
    };
    BufferShim.byteLength = function (s) { return new g.TextEncoder().encode(String(s)).length; };
    BufferShim.isBuffer = function (b) { return b instanceof Uint8Array; };
    g.Buffer = BufferShim;
  }

  // ---------- process ----------
  if (typeof g.process !== 'object') {
    g.process = {
      env: {}, argv: [], version: 'v18.0.0', versions: { node: '18.0.0' },
      nextTick: function (fn) { setTimeout(fn, 0); }
    };
  }

  // ---------- crypto 辅助 ----------
  if (typeof g.crypto !== 'object') {
    g.crypto = {};
  }
  if (!g.crypto.getRandomValues) {
    g.crypto.getRandomValues = function (arr) {
      for (var i = 0; i < arr.length; i++) arr[i] = Math.floor(Math.random() * 256);
      return arr;
    };
  }
  if (!g.crypto.randomUUID) {
    g.crypto.randomUUID = function () {
      var s = '';
      for (var i = 0; i < 32; i++) s += Math.floor(Math.random() * 16).toString(16);
      return s.slice(0, 8) + '-' + s.slice(8, 12) + '-4' + s.slice(13, 16) + '-a' + s.slice(17, 20) + '-' + s.slice(20, 32);
    };
  }

  g.clearTimeout = g.clearTimeout || function () {};

  // ---------- setInterval ----------
  if (typeof g.setInterval !== 'function') {
    g.setInterval = function (fn, ms) {
      var stopped = false;
      function tick() {
        if (stopped) return;
        try { fn(); } finally { if (!stopped) setTimeout(tick, ms); }
      }
      setTimeout(tick, ms);
      return { __interval: true, clear: function () { stopped = true; } };
    };
    g.clearInterval = function (h) { if (h && h.clear) h.clear(); };
  }

  // ---------- CommonJS 模块 ----------
  var __mods = {};
  g.__registerModule = function (name, exportsObj) { __mods[name] = exportsObj; return exportsObj; };
  g.__require = function (name) {
    if (name == null) throw new Error('require: module name required');
    var key = String(name).replace(/\.js$/, '');
    if (Object.prototype.hasOwnProperty.call(__mods, key)) return __mods[key];
    // 常见简写 / 别名
    var aliases = {
      'crypto': 'crypto-js', 'cryptojs': 'crypto-js', 'CryptoJS': 'crypto-js',
      'bigint': 'big-integer', 'jsbn': 'big-integer'
    };
    if (aliases[key] && __mods[aliases[key]]) return __mods[aliases[key]];
    var src = '';
    try { src = sendMessage('ModuleSource', JSON.stringify(key)); } catch (e) { src = ''; }
    if (!src || typeof src !== 'string') {
      throw new Error("Cannot find module '" + name + "'");
    }
    var module = { exports: {} };
    try {
      var factory = new Function('module', 'exports', 'require', 'global', src);
      factory(module, module.exports, g.__require, g);
    } catch (e) {
      throw new Error("Error loading module '" + name + "': " + (e && e.message ? e.message : e));
    }
    __mods[key] = module.exports;
    return module.exports;
  };
  g.require = g.__require;

  // ---------- fetch（Dart HTTP 桥） ----------
  var __fetchSeq = 0;
  var __fetchPending = {};
  g.__fetchFinish = function (id, payloadJson) {
    var p = __fetchPending[id];
    if (!p) return;
    delete __fetchPending[id];
    var d;
    try { d = JSON.parse(payloadJson); } catch (e) { d = { status: 0, body: '' }; }
    p(d);
  };
  g.fetch = function (url, options) {
    options = options || {};
    return new Promise(function (resolve) {
      var id = ++__fetchSeq;
      var req = {
        id: id,
        url: String(url),
        method: String(options.method || 'GET').toUpperCase(),
        headers: options.headers || {},
        body: options.body === undefined || options.body === null ? null : String(options.body)
      };
      __fetchPending[id] = function (d) {
        var headers = d.headers || {};
        resolve({
          ok: d.status >= 200 && d.status < 300,
          status: d.status,
          statusText: d.statusText || '',
          url: req.url,
          headers: {
            get: function (k) {
              var lk = String(k).toLowerCase();
              for (var n in headers) if (String(n).toLowerCase() === lk) return headers[n];
              return null;
            },
            forEach: function (fn) { Object.keys(headers).forEach(function (n) { fn(headers[n], n); }); }
          },
          text: function () { return Promise.resolve(d.body || ''); },
          json: function () { try { return Promise.resolve(JSON.parse(d.body || 'null')); } catch (e) { return Promise.reject(e); } },
          arrayBuffer: function () {
            var bin = atob(d.bodyBase64 || '');
            var bytes = new Uint8Array(bin.length);
            for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
            return Promise.resolve(bytes.buffer);
          },
          blob: function () {
            var bin = atob(d.bodyBase64 || '');
            var bytes = new Uint8Array(bin.length);
            for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
            return Promise.resolve({ size: bytes.length, type: headers['content-type'] || '', arrayBuffer: function () { return Promise.resolve(bytes.buffer); } });
          }
        });
      };
      try {
        sendMessage('Fetch', JSON.stringify(req));
      } catch (e) {
        globalThis.__fetchFinish(req.id, JSON.stringify({ status: 0, body: String(e) }));
      }
    });
  };

  // ---------- 结果序列化（去环、去内部字段） ----------
  g.__safeStringify = function (value) {
    try {
      return JSON.stringify(value, function (k, v) {
        // 插件内部字段（_src / _srcOrder / $ 等）必须原样回传，否则 getMediaSource 取不到链。
        if (typeof v === 'function') return undefined;
        if (typeof v === 'bigint') return v.toString();
        return v;
      });
    } catch (e) {
      try { return JSON.stringify(String(value)); } catch (e2) { return 'null'; }
    }
  };

  // ---------- 插件调用入口 ----------
  g.__invoke = function (method, args) {
    return new Promise(function (resolve) {
      var done = false;
      function finish(obj) {
        if (done) return;
        done = true;
        resolve(g.__safeStringify(obj));
      }
      try {
        var fn = g.__plugin && g.__plugin[method];
        if (typeof fn !== 'function') {
          finish({ ok: false, err: 'UNSUPPORTED', unsupported: true });
          return;
        }
        Promise.resolve(fn.apply(g.__plugin, args || [])).then(
          function (v) { finish({ ok: true, value: v === undefined ? null : v }); },
          function (e) { finish({ ok: false, err: String((e && (e.message || e)) || e) + ' @ ' + String((e && e.stack) || '') }); }
        );
      } catch (e) {
        finish({ ok: false, err: String((e && (e.stack || e.message)) || e) });
      }
    });
  };
})();
