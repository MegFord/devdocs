/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS104: Avoid inline assignments
 * DS207: Consider shorter variations of null checks
 * DS208: Avoid top-level this
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
this.Events = {
  on(event, callback) {
    if (event.indexOf(' ') >= 0) {
      for (let name of Array.from(event.split(' '))) {
        this.on(name, callback);
      }
    } else {
      let base;
      (((base = this._callbacks != null ? this._callbacks : (this._callbacks = {})))[event] != null ? base[event] : (base[event] = [])).push(callback);
    }
    return this;
  },

  off(event, callback) {
    let callbacks, index;
    if (event.indexOf(' ') >= 0) {
      for (let name of Array.from(event.split(' '))) {
        this.off(name, callback);
      }
    } else if ((callbacks = this._callbacks != null ? this._callbacks[event] : undefined) && ((index = callbacks.indexOf(callback)) >= 0)) {
      callbacks.splice(index, 1);
      if (!callbacks.length) {
        delete this._callbacks[event];
      }
    }
    return this;
  },

  trigger(event, ...args) {
    let callbacks;
    this.eventInProgress = {
      name: event,
      args
    };
    if (callbacks = this._callbacks != null ? this._callbacks[event] : undefined) {
      for (let callback of Array.from(callbacks.slice(0))) {
        if (typeof callback === 'function') {
          callback(...Array.from(args || []));
        }
      }
    }
    this.eventInProgress = null;
    if (event !== 'all') {
      this.trigger('all', event, ...Array.from(args));
    }
    return this;
  },

  removeEvent(event) {
    if (this._callbacks != null) {
      for (let name of Array.from(event.split(' '))) {
        delete this._callbacks[name];
      }
    }
    return this;
  }
};