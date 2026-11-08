/* @react-native-cookies/cookies 兼容占位：插件里的登录态接口在爽听中不做持久 Cookie 注入，
 * 返回空对象，避免因缺模块而整体加载失败。 */
module.exports = (function () {
  'use strict';
  var empty = Promise.resolve({});
  var api = {
    get: function () { return empty; },
    getAll: function () { return empty; },
    set: function () { return Promise.resolve(true); },
    clearAll: function () { return Promise.resolve(true); },
    clearByName: function () { return Promise.resolve(true); },
    flush: function () { return Promise.resolve(true); }
  };
  api.default = api;
  return api;
})();
