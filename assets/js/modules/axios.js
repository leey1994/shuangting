/* 爽听内置 axios 兼容层（基于宿主 fetch）
 * 覆盖 MusicFree 插件常用能力：get/post/put/delete/request、params、headers、
 * data（JSON / 表单字符串 / FormData）、responseType、超时、基础拦截器。
 */
module.exports = (function () {
  'use strict';

  function isPlainObject(v) {
    return v && typeof v === 'object' && Object.prototype.toString.call(v) === '[object Object]';
  }

  function encode(v) {
    try { return encodeURIComponent(v); } catch (e) { return String(v); }
  }

  function serializeParams(params, serializer) {
    if (!params) return '';
    if (typeof serializer === 'function') return serializer(params);
    if (typeof params === 'string') return params;
    // 优先用 qs（插件常带复杂嵌套参数）
    try {
      var qs = require('qs');
      if (qs && typeof qs.stringify === 'function') {
        return qs.stringify(params, { arrayFormat: 'repeat' });
      }
    } catch (e) {}
    var parts = [];
    function walk(prefix, value) {
      if (value === null || value === undefined) return;
      if (Array.isArray(value)) {
        value.forEach(function (v) { walk(prefix, v); });
      } else if (isPlainObject(value)) {
        Object.keys(value).forEach(function (k) {
          walk(prefix ? prefix + '[' + k + ']' : k, value[k]);
        });
      } else {
        parts.push(encode(prefix) + '=' + encode(value));
      }
    }
    Object.keys(params).forEach(function (k) { walk(k, params[k]); });
    return parts.join('&');
  }

  function mergeHeaders(base, extra) {
    var out = {};
    Object.keys(base || {}).forEach(function (k) { out[k.toLowerCase()] = base[k]; });
    Object.keys(extra || {}).forEach(function (k) { out[k.toLowerCase()] = extra[k]; });
    return out;
  }

  function normalizeHeaders(h) {
    if (!h) return {};
    if (typeof h.toJSON === 'function') h = h.toJSON();
    if (Array.isArray(h)) {
      var o = {};
      h.forEach(function (p) { o[p[0]] = p[1]; });
      return o;
    }
    return h;
  }

  function buildUrl(config) {
    var url = config.url || '';
    if (config.baseURL && !/^([a-z]+:)?\/\//i.test(url)) {
      url = String(config.baseURL).replace(/\/+$/, '') + '/' + url.replace(/^\/+/, '');
    }
    var qs = serializeParams(config.params, config.paramsSerializer);
    if (qs) url += (url.indexOf('?') >= 0 ? '&' : '?') + qs;
    return url;
  }

  function isFormData(body) {
    return body && typeof body === 'object' && typeof body.append === 'function' && !(body instanceof ArrayBuffer);
  }

  function request(config) {
    config = config || {};
    config.headers = mergeHeaders(config.headers && config.headers.common, config.headers);
    config.headers = mergeHeaders(config.headers, config.headers && config.headers[config.method]);
    var method = String(config.method || 'get').toUpperCase();
    var url = buildUrl(config);
    var headers = normalizeHeaders(config.headers);
    var body = config.data;

    if (body !== undefined && body !== null) {
      if (typeof body === 'string') {
        if (!hasHeader(headers, 'content-type')) headers['Content-Type'] = 'application/x-www-form-urlencoded';
      } else if (isFormData(body)) {
        // fetch 会自行设置 boundary
      } else if (body instanceof ArrayBuffer || ArrayBuffer.isView(body)) {
        // 直接发送
      } else if (isPlainObject(body) || Array.isArray(body)) {
        body = JSON.stringify(body);
        if (!hasHeader(headers, 'content-type')) headers['Content-Type'] = 'application/json';
      } else {
        body = String(body);
      }
    }

    var fetchOptions = {
      method: method,
      headers: headers,
      body: method === 'GET' || method === 'HEAD' ? undefined : body,
      credentials: config.withCredentials ? 'include' : 'omit'
    };

    var timeout = config.timeout;
    var p = fetch(url, fetchOptions).then(function (res) {
      var dataPromise;
      var type = (config.responseType || '').toLowerCase();
      if (type === 'json') dataPromise = res.text().then(function (t) { try { return JSON.parse(t); } catch (e) { return null; } });
      else if (type === 'text' || type === '') {
        dataPromise = res.text().then(function (t) {
          var ct = (res.headers && res.headers.get && res.headers.get('content-type')) || '';
          if (type === '' && /json/i.test(ct)) {
            try { return JSON.parse(t); } catch (e) { return t; }
          }
          return t;
        });
      } else {
        dataPromise = res.text();
      }
      return dataPromise.then(function (data) {
        var response = {
          data: data,
          status: res.status,
          statusText: res.statusText,
          headers: headersToObject(res.headers),
          config: config,
          request: null,
          url: url
        };
        var validate = config.validateStatus || function (s) { return s >= 200 && s < 300; };
        if (!validate(res.status)) {
          var err = new Error('Request failed with status code ' + res.status);
          err.response = response;
          err.config = config;
          err.isAxiosError = true;
          throw err;
        }
        return response;
      });
    });

    if (timeout && timeout > 0) {
      p = Promise.race([
        p,
        new Promise(function (_, reject) {
          setTimeout(function () {
            var e = new Error('timeout of ' + timeout + 'ms exceeded');
            e.code = 'ECONNABORTED';
            e.config = config;
            reject(e);
          }, timeout);
        })
      ]);
    }
    return p;
  }

  function hasHeader(h, name) {
    var lname = name.toLowerCase();
    return Object.keys(h || {}).some(function (k) { return k.toLowerCase() === lname; });
  }

  function headersToObject(h) {
    var out = {};
    try {
      if (h && typeof h.forEach === 'function') {
        h.forEach(function (v, k) { out[k] = v; });
      } else if (h && typeof h.entries === 'function') {
        h.entries().forEach(function (p) { out[p[0]] = p[1]; });
      }
    } catch (e) {}
    return out;
  }

  function createInstance(defaults) {
    var instanceDefaults = JSON.parse(JSON.stringify(defaults || {}));
    var reqInterceptors = [];
    var resInterceptors = [];

    var instance = function (config) {
      var merged = mergeConfig(instanceDefaults, config || {});
      var chain = reqInterceptors.slice();
      // 简化：请求拦截器按注册顺序执行，响应拦截器倒序
      return chain.reduce(function (p, it) {
        return p.then(function (cfg) { return it.fulfilled ? it.fulfilled(cfg) : cfg; });
      }, Promise.resolve(merged)).then(function (cfg) {
        return request(cfg);
      }).then(function (res) {
        return resInterceptors.reduce(function (p, it) {
          return p.then(function (r) { return it.fulfilled ? it.fulfilled(r) : r; });
        }, Promise.resolve(res));
      }, function (err) {
        return resInterceptors.reduce(function (p, it) {
          return p.then(null, function (e) { return it.rejected ? it.rejected(e) : Promise.reject(e); });
        }, Promise.reject(err));
      });
    };

    instance.defaults = instanceDefaults;
    instance.request = function (config) { return instance(config); };
    ['get', 'delete', 'head', 'options'].forEach(function (m) {
      instance[m] = function (url, config) {
        return instance(mergeConfig(config || {}, { url: url, method: m }));
      };
    });
    ['post', 'put', 'patch'].forEach(function (m) {
      instance[m] = function (url, data, config) {
        return instance(mergeConfig(config || {}, { url: url, method: m, data: data }));
      };
    });
    instance.create = function (cfg) { return createInstance(mergeConfig(instanceDefaults, cfg || {})); };
    instance.interceptors = {
      request: {
        use: function (f, r) { reqInterceptors.push({ fulfilled: f, rejected: r }); return reqInterceptors.length - 1; },
        eject: function (i) { reqInterceptors[i] = {}; }
      },
      response: {
        use: function (f, r) { resInterceptors.push({ fulfilled: f, rejected: r }); return resInterceptors.length - 1; },
        eject: function (i) { resInterceptors[i] = {}; }
      }
    };
    instance.all = function (list) { return Promise.all(list); };
    instance.spread = function (fn) { return function (arr) { return fn.apply(null, arr); }; };
    instance.isAxiosError = function (e) { return !!(e && e.isAxiosError); };
    instance.CancelToken = { source: function () { return { token: { promise: new Promise(function () {}) }, cancel: function () {} }; } };
    instance.isCancel = function () { return false; };
    return instance;
  }

  function mergeConfig(a, b) {
    var out = {};
    Object.keys(a || {}).forEach(function (k) { out[k] = a[k]; });
    Object.keys(b || {}).forEach(function (k) {
      if (k === 'headers') out.headers = mergeHeaders(a.headers, b.headers);
      else if (k === 'params' && isPlainObject(a.params) && isPlainObject(b.params)) out.params = Object.assign({}, a.params, b.params);
      else out[k] = b[k];
    });
    return out;
  }

  var axios = createInstance({ headers: { common: {} }, timeout: 0 });
  axios.default = axios;
  axios.create = function (cfg) { return createInstance(cfg || {}); };
  axios.request = function (cfg) { return axios(cfg); };
  ['get', 'delete', 'head', 'options'].forEach(function (m) {
    axios[m] = function (url, config) { return axios(mergeConfig(config || {}, { url: url, method: m })); };
  });
  ['post', 'put', 'patch'].forEach(function (m) {
    axios[m] = function (url, data, config) { return axios(mergeConfig(config || {}, { url: url, method: m, data: data })); };
  });
  axios.all = function (l) { return Promise.all(l); };
  axios.spread = function (fn) { return function (arr) { return fn.apply(null, arr); }; };
  axios.isAxiosError = function (e) { return !!(e && e.isAxiosError); };
  return axios;
})();
