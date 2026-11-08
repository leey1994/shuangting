/* 爽听内置 cheerio 兼容层
 * 面向 MusicFree 插件里最常见的 jQuery 风格 HTML 解析/选择需求：
 *   load / $ / find / text / attr / prop / html / children / first / last / eq / each / map / get ...
 * 选择器支持：tag、*、#id、.class、[attr]、[attr=v]、[attr*=v]、[attr^=v]、[attr$=v]、
 * 后代、'>'、','、:first、:last、:eq(n)、:nth-child(n)、:contains(t)、:not(simple)、:has(simple)。
 */
module.exports = (function () {
  'use strict';

  var VOID = { area: 1, base: 1, br: 1, col: 1, embed: 1, hr: 1, img: 1, input: 1, link: 1, meta: 1, param: 1, source: 1, track: 1, wbr: 1 };
  var RAW = { script: 1, style: 1, textarea: 1, title: 1 };

  var ENTITIES = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: '\u00a0', copy: '\u00a9', reg: '\u00ae', hellip: '\u2026', mdash: '\u2014', ndash: '\u2013', middot: '\u00b7', ldquo: '\u201c', rdquo: '\u201d', lsquo: '\u2018', rsquo: '\u2019' };
  function decodeEntities(s) {
    return String(s).replace(/&(#x?[0-9a-fA-F]+|[a-zA-Z]+);/g, function (m, e) {
      if (e.charAt(0) === '#') {
        var code = e.charAt(1) === 'x' || e.charAt(1) === 'X' ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
        try { return String.fromCodePoint(code); } catch (err) { return m; }
      }
      return Object.prototype.hasOwnProperty.call(ENTITIES, e) ? ENTITIES[e] : m;
    });
  }
  function escapeHtml(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function Node(type, name) {
    this.type = type;
    this.name = name || '';
    this.children = [];
    this.parent = null;
    this.attribs = {};
    this.data = '';
  }
  function appendChild(parent, child) {
    child.parent = parent;
    parent.children.push(child);
    return child;
  }

  function parse(html) {
    var root = new Node('root');
    var stack = [root];
    var src = String(html || '');
    var i = 0;
    function top() { return stack[stack.length - 1]; }

    while (i < src.length) {
      var lt = src.indexOf('<', i);
      if (lt < 0) { if (i < src.length) appendChild(top(), textNode(src.slice(i))); break; }
      if (lt > i) appendChild(top(), textNode(src.slice(i, lt)));

      if (src.substr(lt, 4) === '<!--') {
        var ce = src.indexOf('-->', lt + 4);
        if (ce < 0) ce = src.length;
        // 注释节点不进入文档树（jQuery/cheerio 默认保留，但对插件无意义）
        i = ce + 3;
        continue;
      }
      if (src.substr(lt, 9).toLowerCase() === '<!doctype') {
        var de = src.indexOf('>', lt);
        i = de < 0 ? src.length : de + 1;
        continue;
      }
      if (src.substr(lt, 9) === '<![CDATA[') {
        var cde = src.indexOf(']]>', lt);
        if (cde < 0) cde = src.length;
        appendChild(top(), textNode(src.slice(lt + 9, cde)));
        i = cde + 3;
        continue;
      }
      var gt = findTagEnd(src, lt + 1);
      if (gt < 0) { appendChild(top(), textNode(src.slice(lt))); break; }
      var raw = src.slice(lt + 1, gt);
      i = gt + 1;

      if (raw.charAt(0) === '/') {
        var closeName = raw.slice(1).trim().toLowerCase();
        for (var k = stack.length - 1; k > 0; k--) {
          if (stack[k].name === closeName) { stack.length = k; break; }
        }
        continue;
      }

      var selfClosing = raw.charAt(raw.length - 1) === '/';
      if (selfClosing) raw = raw.slice(0, -1);
      var m = raw.match(/^([a-zA-Z][^\s/>]*)/);
      if (!m) { appendChild(top(), textNode('<' + raw + '>')); continue; }
      var name = m[1].toLowerCase();
      var el = new Node('tag', name);
      el.attribs = parseAttribs(raw.slice(m[1].length));

      if (name === 'html' && root.children.length === 0) {
        // 保持根节点下的 html 结构
      }
      appendChild(top(), el);

      if (VOID[name] || selfClosing) continue;

      if (RAW[name]) {
        var re = new RegExp('</\\s*' + name + '\\s*>', 'i');
        var rest = src.slice(i);
        var mm = re.exec(rest);
        var content = mm ? rest.slice(0, mm.index) : rest;
        if (content) appendChild(el, textNode(content, name === 'script' || name === 'style'));
        i += mm ? mm.index + mm[0].length : rest.length;
        continue;
      }
      stack.push(el);
    }
    return root;
  }

  function findTagEnd(s, from) {
    var quote = '';
    for (var j = from; j < s.length; j++) {
      var c = s.charAt(j);
      if (quote) { if (c === quote) quote = ''; continue; }
      if (c === '"' || c === "'") { quote = c; continue; }
      if (c === '>') return j;
    }
    return -1;
  }

  function textNode(data, raw) {
    var n = new Node('text');
    n.data = data;
    n.raw = !!raw;
    return n;
  }

  function parseAttribs(s) {
    var out = {};
    var re = /([^\s=/>]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g;
    var m;
    while ((m = re.exec(s))) {
      var name = m[1].toLowerCase();
      var val = m[2] !== undefined ? m[2] : m[3] !== undefined ? m[3] : m[4] !== undefined ? m[4] : '';
      out[name] = decodeEntities(val);
    }
    return out;
  }

  // ---------- 选择器 ----------
  function parseSimple(sel) {
    var simple = { tag: null, id: null, classes: [], attrs: [], pseudos: [] };
    var re = /([#.]?[\w-]+|\*|\[[^\]]*\]|:[\w-]+(?:\([^)]*\))?)/g;
    var m;
    while ((m = re.exec(sel))) {
      var t = m[1];
      if (t === '*') { simple.tag = '*'; }
      else if (t.charAt(0) === '#') simple.id = t.slice(1);
      else if (t.charAt(0) === '.') simple.classes.push(t.slice(1));
      else if (t.charAt(0) === '[') {
        var am = t.slice(1, -1).match(/^\s*([^\s~|^$*!=]+)\s*(?:([~|^$*!]?=)\s*(?:"([^"]*)"|'([^']*)'|([^\]]*)))?\s*$/);
        if (am) simple.attrs.push({ name: am[1].toLowerCase(), op: am[2] || '', value: am[3] !== undefined ? am[3] : am[4] !== undefined ? am[4] : am[5] !== undefined ? am[5] : '' });
      } else if (t.charAt(0) === ':') {
        var pm = t.match(/^:([\w-]+)(?:\((.*)\))?$/);
        if (pm) simple.pseudos.push({ name: pm[1].toLowerCase(), arg: pm[2] });
      } else {
        simple.tag = t.toLowerCase();
      }
    }
    return simple;
  }

  function parseSelector(sel) {
    // returns groups: [{tokens:[{comb, simple}]}]
    var groups = [];
    var parts = splitTop(sel, ',');
    parts.forEach(function (part) {
      part = part.trim();
      if (!part) return;
      var tokens = [];
      var buf = '';
      var comb = ' ';
      var depth = 0, quote = '';
      for (var i = 0; i < part.length; i++) {
        var c = part.charAt(i);
        if (quote) { buf += c; if (c === quote) quote = ''; continue; }
        if (c === '"' || c === "'") { quote = c; buf += c; continue; }
        if (c === '(' || c === '[') depth++;
        if (c === ')' || c === ']') depth--;
        if (depth === 0 && (c === '>' || c === '+' || c === '~' || /\s/.test(c))) {
          if (buf.trim()) { tokens.push({ comb: comb, simple: parseSimple(buf.trim()) }); buf = ''; }
          if (!/\s/.test(c)) comb = c;
          else if (comb === ' ') comb = ' ';
          continue;
        }
        buf += c;
      }
      if (buf.trim()) tokens.push({ comb: comb, simple: parseSimple(buf.trim()) });
      if (tokens.length) {
        tokens[0].comb = ' ';
        groups.push(tokens);
      }
    });
    return groups;
  }

  function splitTop(s, ch) {
    var out = [], buf = '', depth = 0, quote = '';
    for (var i = 0; i < s.length; i++) {
      var c = s.charAt(i);
      if (quote) { buf += c; if (c === quote) quote = ''; continue; }
      if (c === '"' || c === "'") { quote = c; buf += c; continue; }
      if (c === '(' || c === '[') depth++;
      if (c === ')' || c === ']') depth--;
      if (depth === 0 && c === ch) { out.push(buf); buf = ''; continue; }
      buf += c;
    }
    out.push(buf);
    return out;
  }

  function matchSimple(node, simple, root) {
    if (node.type !== 'tag') return false;
    if (simple.tag && simple.tag !== '*' && node.name !== simple.tag) return false;
    if (simple.id && node.attribs.id !== simple.id) return false;
    for (var i = 0; i < simple.classes.length; i++) {
      if (!hasClass(node, simple.classes[i])) return false;
    }
    for (var j = 0; j < simple.attrs.length; j++) {
      var a = simple.attrs[j];
      var v = node.attribs[a.name];
      if (v === undefined) return false;
      if (!a.op) continue;
      if (a.op === '=' && v !== a.value) return false;
      if (a.op === '!=' && v === a.value) return false;
      if (a.op === '*=' && v.indexOf(a.value) < 0) return false;
      if (a.op === '^=' && v.indexOf(a.value) !== 0) return false;
      if (a.op === '$=' && v.slice(-a.value.length) !== a.value) return false;
      if (a.op === '~=' && (' ' + v + ' ').indexOf(' ' + a.value + ' ') < 0) return false;
      if (a.op === '|=' && v !== a.value && v.indexOf(a.value + '-') !== 0) return false;
    }
    for (var k = 0; k < simple.pseudos.length; k++) {
      var p = simple.pseudos[k];
      if (p.name === 'first' || p.name === 'last' || p.name === 'eq') continue; // 集合级伪类
      if (p.name === 'nth-child') {
        var idx = indexOfNode(node);
        var n = parseInt(p.arg, 10);
        if (isNaN(n) || idx !== n - 1) return false;
      } else if (p.name === 'first-child') {
        if (indexOfNode(node) !== 0) return false;
      } else if (p.name === 'last-child') {
        var sib = siblingsOf(node);
        if (sib[sib.length - 1] !== node) return false;
      } else if (p.name === 'contains') {
        var needle = String(p.arg || '').replace(/^['"]|['"]$/g, '');
        if (textOf(node).indexOf(needle) < 0) return false;
      } else if (p.name === 'not') {
        if (matchSimple(node, parseSimple(p.arg || ''), root)) return false;
      } else if (p.name === 'has') {
        if (queryWithin(node, p.arg || '').length === 0) return false;
      } else if (p.name === 'empty') {
        if (node.children.length) return false;
      }
    }
    return true;
  }

  function hasClass(node, cls) {
    var c = node.attribs['class'];
    if (!c) return false;
    return (' ' + c + ' ').indexOf(' ' + cls + ' ') >= 0;
  }
  function indexOfNode(node) {
    var p = node.parent;
    if (!p) return 0;
    var tags = p.children.filter(function (n) { return n.type === 'tag'; });
    return tags.indexOf(node);
  }
  function siblingsOf(node) {
    var p = node.parent;
    if (!p) return [];
    return p.children.filter(function (n) { return n.type === 'tag'; });
  }
  function textOf(node) {
    if (node.type === 'text') return node.data;
    var out = '';
    node.children.forEach(function (c) { out += textOf(c); });
    return out;
  }

  function descendants(node, out) {
    node.children.forEach(function (c) {
      if (c.type === 'tag') out.push(c);
      descendants(c, out);
    });
    return out;
  }

  function queryWithin(context, selector) {
    var groups = parseSelector(selector);
    var result = [];
    groups.forEach(function (tokens) {
      var current = [context];
      for (var i = 0; i < tokens.length; i++) {
        var tk = tokens[i];
        var next = [];
        current.forEach(function (node) {
          var candidates = [];
          if (i === 0) {
            if (tk.comb === '>') candidates = node.children.filter(function (c) { return c.type === 'tag'; });
            else candidates = descendants(node, []);
            if (tk.comb === '+' || tk.comb === '~') candidates = [];
          } else if (tk.comb === '>') {
            candidates = node.children.filter(function (c) { return c.type === 'tag'; });
          } else if (tk.comb === '+') {
            var sib = siblingsOf(node);
            var at = sib.indexOf(node);
            candidates = at >= 0 && sib[at + 1] ? [sib[at + 1]] : [];
          } else if (tk.comb === '~') {
            var ss = siblingsOf(node);
            var ai = ss.indexOf(node);
            candidates = ai >= 0 ? ss.slice(ai + 1) : [];
          } else {
            candidates = descendants(node, []);
          }
          candidates.forEach(function (c) {
            if (matchSimple(c, tk.simple, context)) next.push(c);
          });
        });
        current = next;
        if (!current.length) break;
      }
      // 集合级伪类
      var last = tokens[tokens.length - 1].simple;
      if (last && last.pseudos) {
        last.pseudos.forEach(function (p) {
          if (p.name === 'first') current = current.slice(0, 1);
          else if (p.name === 'last') current = current.slice(-1);
          else if (p.name === 'eq') { var n = parseInt(p.arg, 10); current = n < 0 ? current.slice(n) : [current[n]].filter(Boolean); }
        });
      }
      current.forEach(function (n) { if (result.indexOf(n) < 0) result.push(n); });
    });
    return result;
  }

  // ---------- Cheerio 集合 ----------
  function Cheerio(nodes, root) {
    this._nodes = nodes || [];
    this._root = root || null;
    this.length = this._nodes.length;
    for (var i = 0; i < this._nodes.length; i++) this[i] = this._nodes[i];
  }

  function wrap(nodes, root) { return new Cheerio(nodes, root); }
  function unique(nodes) {
    var out = [];
    nodes.forEach(function (n) { if (n && out.indexOf(n) < 0) out.push(n); });
    return out;
  }

  Cheerio.prototype.find = function (selector) {
    var out = [];
    this._nodes.forEach(function (n) {
      if (n.type === 'tag' || n.type === 'root') out = out.concat(queryWithin(n, selector));
    });
    return wrap(unique(out), this._root);
  };
  Cheerio.prototype.filter = function (selector) {
    var self = this;
    if (typeof selector === 'function') {
      return wrap(this._nodes.filter(function (n, i) { return selector.call(n, i, n); }), this._root);
    }
    var groups = parseSelector(selector);
    var out = this._nodes.filter(function (n) {
      return groups.some(function (tokens) { return matchSimple(n, tokens[tokens.length - 1].simple, self._root); });
    });
    return wrap(out, this._root);
  };
  Cheerio.prototype.not = function (selector) {
    var groups = parseSelector(selector);
    return wrap(this._nodes.filter(function (n) {
      return !groups.some(function (tokens) { return matchSimple(n, tokens[tokens.length - 1].simple, null); });
    }), this._root);
  };
  Cheerio.prototype.is = function (selector) {
    var groups = parseSelector(selector);
    return this._nodes.some(function (n) {
      return groups.some(function (tokens) { return matchSimple(n, tokens[tokens.length - 1].simple, null); });
    });
  };
  Cheerio.prototype.has = function (selector) {
    return wrap(this._nodes.filter(function (n) { return queryWithin(n, selector).length > 0; }), this._root);
  };
  Cheerio.prototype.closest = function (selector) {
    var out = [];
    this._nodes.forEach(function (n) {
      var cur = n.parent;
      while (cur && cur.type !== 'root') {
        if (matchSimple(cur, parseSelector(selector)[0][0].simple, null)) { out.push(cur); break; }
        cur = cur.parent;
      }
    });
    return wrap(unique(out), this._root);
  };
  Cheerio.prototype.parent = function () {
    return wrap(unique(this._nodes.map(function (n) { return n.parent && n.parent.type !== 'root' ? n.parent : null; })), this._root);
  };
  Cheerio.prototype.parents = function (selector) {
    var out = [];
    this._nodes.forEach(function (n) {
      var cur = n.parent;
      while (cur && cur.type !== 'root') {
        if (!selector || matchSimple(cur, parseSelector(selector)[0][0].simple, null)) out.push(cur);
        cur = cur.parent;
      }
    });
    return wrap(unique(out), this._root);
  };
  Cheerio.prototype.children = function (selector) {
    var out = [];
    this._nodes.forEach(function (n) {
      n.children.forEach(function (c) { if (c.type === 'tag') out.push(c); });
    });
    if (selector) out = out.filter(function (n) { return matchSimple(n, parseSelector(selector)[0][0].simple, null); });
    return wrap(out, this._root);
  };
  Cheerio.prototype.siblings = function (selector) {
    var out = [];
    this._nodes.forEach(function (n) {
      siblingsOf(n).forEach(function (s) { if (s !== n) out.push(s); });
    });
    if (selector) out = out.filter(function (n) { return matchSimple(n, parseSelector(selector)[0][0].simple, null); });
    return wrap(unique(out), this._root);
  };
  Cheerio.prototype.next = function (selector) {
    var out = [];
    this._nodes.forEach(function (n) {
      var sib = siblingsOf(n), at = sib.indexOf(n);
      if (at >= 0 && sib[at + 1]) out.push(sib[at + 1]);
    });
    if (selector) out = out.filter(function (n) { return matchSimple(n, parseSelector(selector)[0][0].simple, null); });
    return wrap(out, this._root);
  };
  Cheerio.prototype.prev = function (selector) {
    var out = [];
    this._nodes.forEach(function (n) {
      var sib = siblingsOf(n), at = sib.indexOf(n);
      if (at > 0) out.push(sib[at - 1]);
    });
    if (selector) out = out.filter(function (n) { return matchSimple(n, parseSelector(selector)[0][0].simple, null); });
    return wrap(out, this._root);
  };
  Cheerio.prototype.eq = function (i) {
    var n = i < 0 ? this._nodes[this._nodes.length + i] : this._nodes[i];
    return wrap(n ? [n] : [], this._root);
  };
  Cheerio.prototype.first = function () { return this.eq(0); };
  Cheerio.prototype.last = function () { return this.eq(-1); };
  Cheerio.prototype.slice = function (a, b) { return wrap(this._nodes.slice(a, b), this._root); };
  Cheerio.prototype.get = function (i) { return i === undefined ? this._nodes.slice() : this._nodes[i < 0 ? this._nodes.length + i : i]; };
  Cheerio.prototype.toArray = function () { return this._nodes.slice(); };
  Cheerio.prototype.index = function (sel) {
    if (sel === undefined) {
      var n = this._nodes[0];
      return n ? indexOfNode(n) : -1;
    }
    var target = sel instanceof Cheerio ? sel._nodes[0] : sel;
    return this._nodes.indexOf(target);
  };
  Cheerio.prototype.each = function (fn) {
    for (var i = 0; i < this._nodes.length; i++) {
      if (fn.call(this._nodes[i], i, this._nodes[i]) === false) break;
    }
    return this;
  };
  Cheerio.prototype.map = function (fn) {
    var out = [];
    this._nodes.forEach(function (n, i) {
      var r = fn.call(n, i, n);
      if (r !== null && r !== undefined) out.push(r instanceof Cheerio ? r._nodes[0] : r);
    });
    return wrap(out, this._root);
  };
  Cheerio.prototype.attr = function (name, value) {
    if (value === undefined && typeof name !== 'object') {
      var n = this._nodes[0];
      return n && n.attribs ? n.attribs[name] : undefined;
    }
    if (typeof name === 'object') {
      Object.keys(name).forEach(function (k) { this.attr(k, name[k]); }, this);
      return this;
    }
    this._nodes.forEach(function (n) { if (n.attribs) n.attribs[name] = String(value); });
    return this;
  };
  Cheerio.prototype.removeAttr = function (name) {
    this._nodes.forEach(function (n) { if (n.attribs) delete n.attribs[name]; });
    return this;
  };
  Cheerio.prototype.prop = function (name, value) {
    if (name === 'tagName') return this._nodes[0] ? this._nodes[0].name.toUpperCase() : undefined;
    if (name === 'outerHTML') return this._nodes[0] ? serialise(this._nodes[0]) : undefined;
    if (name === 'nodeName') return this._nodes[0] ? this._nodes[0].name.toUpperCase() : undefined;
    if (name === 'textContent') return this.text();
    if (value === undefined) return this.attr(name);
    return this.attr(name, value);
  };
  Cheerio.prototype.data = function (name, value) {
    if (value !== undefined) { this.attr('data-' + name, value); return this; }
    if (name !== undefined) {
      var v = this.attr('data-' + name);
      if (v === undefined) return undefined;
      try { return JSON.parse(v); } catch (e) { return v; }
    }
    var n = this._nodes[0], out = {};
    if (!n || !n.attribs) return out;
    Object.keys(n.attribs).forEach(function (k) {
      if (k.indexOf('data-') === 0) {
        var key = k.slice(5).replace(/-([a-z])/g, function (m, c) { return c.toUpperCase(); });
        var val = n.attribs[k];
        try { val = JSON.parse(val); } catch (e) {}
        out[key] = val;
      }
    });
    return out;
  };
  Cheerio.prototype.val = function (v) {
    if (v === undefined) {
      var n = this._nodes[0];
      return n && n.attribs ? (n.attribs.value || '') : '';
    }
    return this.attr('value', v);
  };
  Cheerio.prototype.text = function (v) {
    if (v === undefined) {
      return this._nodes.map(function (n) { return textOf(n); }).join('');
    }
    this._nodes.forEach(function (n) {
      n.children = []; n.type = 'tag';
      appendChild(n, textNode(String(v)));
    });
    return this;
  };
  Cheerio.prototype.html = function (v) {
    if (v === undefined) {
      var n = this._nodes[0];
      if (!n) return null;
      return n.children.map(serialise).join('');
    }
    this._nodes.forEach(function (n) {
      n.children = [];
      var frag = parse(String(v));
      frag.children.forEach(function (c) { appendChild(n, c); });
    });
    return this;
  };
  Cheerio.prototype.toString = function () {
    return this._nodes.map(serialise).join('');
  };
  Cheerio.prototype.hasClass = function (c) { return this._nodes.some(function (n) { return hasClass(n, c); }); };
  Cheerio.prototype.addClass = function (c) {
    this._nodes.forEach(function (n) {
      if (!n.attribs) n.attribs = {};
      var cur = n.attribs['class'] ? n.attribs['class'].split(/\s+/) : [];
      String(c).split(/\s+/).forEach(function (x) { if (x && cur.indexOf(x) < 0) cur.push(x); });
      n.attribs['class'] = cur.join(' ');
    });
    return this;
  };
  Cheerio.prototype.removeClass = function (c) {
    this._nodes.forEach(function (n) {
      if (!n.attribs || !n.attribs['class']) return;
      n.attribs['class'] = n.attribs['class'].split(/\s+/).filter(function (x) { return x && x !== c; }).join(' ');
    });
    return this;
  };
  Cheerio.prototype.toggleClass = function (c) {
    this._nodes.forEach(function (n) { if (hasClass(n, c)) removeOne(n, c); else addOne(n, c); });
    return this;
  };
  function addOne(n, c) {
    if (!n.attribs) n.attribs = {};
    var cur = n.attribs['class'] ? n.attribs['class'].split(/\s+/) : [];
    if (cur.indexOf(c) < 0) cur.push(c);
    n.attribs['class'] = cur.join(' ');
  }
  function removeOne(n, c) {
    if (!n.attribs || !n.attribs['class']) return;
    n.attribs['class'] = n.attribs['class'].split(/\s+/).filter(function (x) { return x && x !== c; }).join(' ');
  }
  Cheerio.prototype.append = function (content) {
    var self = this;
    this._nodes.forEach(function (n) {
      if (content instanceof Cheerio) content._nodes.forEach(function (c) { appendChild(n, cloneNode(c)); });
      else if (typeof content === 'string') {
        var frag = parse(content);
        frag.children.forEach(function (c) { appendChild(n, cloneNode(c)); });
      }
    });
    return this;
  };
  Cheerio.prototype.prepend = function (content) {
    this._nodes.forEach(function (n) {
      var frag = parse(content instanceof Cheerio ? content.toString() : String(content));
      frag.children.reverse().forEach(function (c) { c.parent = n; n.children.unshift(c); });
    });
    return this;
  };
  Cheerio.prototype.remove = function () {
    this._nodes.forEach(function (n) {
      if (n.parent) {
        var i = n.parent.children.indexOf(n);
        if (i >= 0) n.parent.children.splice(i, 1);
      }
    });
    return this;
  };
  Cheerio.prototype.empty = function () {
    this._nodes.forEach(function (n) { n.children = []; });
    return this;
  };
  Cheerio.prototype.clone = function () {
    return wrap(this._nodes.map(cloneNode), this._root);
  };
  Cheerio.prototype.replaceWith = function (content) {
    this._nodes.forEach(function (n) {
      if (!n.parent) return;
      var i = n.parent.children.indexOf(n);
      if (i < 0) return;
      var frag = parse(typeof content === 'string' ? content : String(content));
      var nodes = frag.children.map(function (c) { return cloneNode(c); });
      nodes.forEach(function (c) { c.parent = n.parent; });
      n.parent.children.splice(i, 1, ...nodes);
    });
    return this;
  };

  function cloneNode(n) {
    if (n.type === 'text') return textNode(n.data, n.raw);
    var c = new Node(n.type, n.name);
    c.attribs = Object.assign({}, n.attribs);
    c.data = n.data;
    c.raw = n.raw;
    n.children.forEach(function (ch) { appendChild(c, cloneNode(ch)); });
    return c;
  }

  function serialise(n) {
    if (n.type === 'text') return n.raw ? n.data : escapeHtml(n.data);
    if (n.type === 'root') return n.children.map(serialise).join('');
    var attrs = '';
    Object.keys(n.attribs || {}).forEach(function (k) {
      attrs += ' ' + k + '="' + String(n.attribs[k]).replace(/&/g, '&amp;').replace(/"/g, '&quot;') + '"';
    });
    var name = n.name;
    if (name === 'script' || name === 'style') {
      return '<' + name + attrs + '>' + n.children.map(serialise).join('') + '</' + name + '>';
    }
    if (VOID[name]) return '<' + name + attrs + '>';
    return '<' + name + attrs + '>' + n.children.map(serialise).join('') + '</' + name + '>';
  }

  // ---------- 对外 API ----------
  function load(html) {
    var root = parse(html);
    var $ = function (selector, context) {
      if (selector instanceof Cheerio) return selector;
      if (selector && typeof selector === 'object' && selector.type) {
        // DOM node
        return wrap([selector], root);
      }
      if (typeof selector === 'function') {
        // $(fn) DOM ready
        try { selector(); } catch (e) {}
        return wrap([], root);
      }
      if (selector === undefined || selector === null || selector === '') return wrap([], root);
      if (typeof selector === 'string' && selector.charAt(0) === '<') {
        var frag = parse(selector);
        return wrap(frag.children, root);
      }
      var ctxList = context ? wrapify(context, root) : [root];
      var out = [];
      ctxList.forEach(function (ctx) { out = out.concat(queryWithin(ctx, selector)); });
      return wrap(unique(out), root);
    };
    $.root = function () { return wrap([root], root); };
    $.html = function (sel) {
      if (sel === undefined) return root.children.map(serialise).join('');
      return $(sel).toString();
    };
    $.parseHTML = function (s) { return parse(s).children; };
    $.contains = function (a, b) {
      var cur = b;
      while (cur) { if (cur === a) return true; cur = cur.parent; }
      return false;
    };
    $.load = load;
    return $;
  }

  function wrapify(x, root) {
    if (x instanceof Cheerio) return x._nodes;
    if (Array.isArray(x)) return x;
    if (x && (x.type === 'tag' || x.type === 'root')) return [x];
    return [];
  }

  load.parseHTML = function (s) { return parse(s).children; };
  load.html = function (s) { return parse(s).children.map(serialise).join(''); };
  load.load = load;
  load.Cheerio = Cheerio;
  load.default = load;
  return load;
})();
