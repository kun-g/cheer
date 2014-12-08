"use strict";
moment = require('./moment');
var libTime = require('./timeUtils.js');

function Counter (config) {
  this.config = config;

  var savingCfg = {
    config: config,
    counter: config.initial_value,
    time: moment().format(),
  };

  this.counter = this.config.initial_value; //Delete this in coffee

  // uncomment this in coffee
  // super(config, savingCfg, {})
}

Counter.prototype.initialize = function () {
};

Counter.prototype.isFullfiled = function (time) {
  this.update(time);
  if (this.config.uplimit) return this.counter >= this.config.uplimit;
  return false;
}
Counter.prototype.notFullfiled = function (time) {
  return !this.isFullfiled(time);
}

Counter.prototype.update = function (time) {
  this.incr(0, time);
};

Counter.prototype.decr = function (delta, time) {
  return this.incr(-delta, time);
};
Counter.prototype.incr = function (delta, time) {
  var duration = this.config.duration;
  var units = this.config.units;

  var theData = {
    ThisCounter: {
      time: this.time
    }
  };

  time = moment(time);
  if (delta) this.time = time.format();

  if (this.time) {
    var duration = this.config.duration;
    if (duration) {
      if (!libTime.verify(time, duration, theData)) {
        this.counter = 0;
        log('incr:', 'check duration failed');
      }
    }

    var combo = this.config.combo;
    if (combo) {
      if (!libTime.verify(time, combo, theData)) {
        this.counter = 0;
        log('incr:', 'check combo failed');
      }
    }

    var countDown = this.config.count_down;
    if (countDown) {
      if (libTime.verify(time, countDown, theData)) {
        delta = 0;
        log('incr:', 'check countDown failed');
      }
    }
  }

  var uplimit = this.config.uplimit;
  if (uplimit && this.counter + delta > uplimit) {
    delta = uplimit - this.counter;
  }

  this.counter += delta;
  log('Incr', delta, this.counter);
};

Counter.prototype.reset = function () {
  this.counter = config.initial_value;
}

Counter.prototype.fulfill = function () {
  if (this.config.uplimit) {
    this.counter = config.uplimit;
  }
};

exports.Counter = Counter;

var testConfig = {
  rmb: {
    initial_value: 0
  },
  pvp_win: {
    initial_value: 0,
    uplimit: 4,
    combo: { duration: { minute: 10 }, time: 'time@ThisCounter' }
  },
  check_in: {
    initial_value: 0,
    count_down: { time: 'time@ThisCounter', units: 'day' },
    duration: { time: 'time@ThisCounter', units: 'month' }
  },
  milionaire_goblin: {
    initial_value: 0,
    uplimit: 3,
    duration: { time: 'time@ThisCounter', units: 'day' }
  },
};

var counterTests = [
  function() {
    var counter = new Counter(testConfig.rmb);
    log(' '+1); counter.incr(1); if (counter.counter != 1) return false;
    log(' '+2); counter.incr(1); if (counter.counter != 2) return false;
    log(' '+3); counter.decr(1); if (counter.counter != 1) return false;
    log(' '+4); counter.update(); if (counter.counter != 1) return false;
    return true;
  },
  function() {
    var counter = new Counter(testConfig.pvp_win);
    log(' '+1); counter.incr(1, "2012-12-12"); if (counter.counter != 1) return false;
    log(' '+2); counter.incr(1, "2012-12-12"); if (counter.counter != 2) return false;
    log(' '+3); counter.incr(1, "2012-12-12T00:11:00"); if (counter.counter != 1) return false;
    log(' '+4); counter.incr(1, "2012-12-12T00:20:00"); if (counter.counter != 2) return false;
    log(' '+5); counter.update("2012-12-13"); if (counter.counter != 0) return false;
    log(' '+6); counter.incr(1, "2012-12-13"); if (counter.counter != 1) return false;
    log(' '+7); counter.incr(1, "2012-12-13"); if (counter.counter != 2) return false;
    log(' '+8); counter.incr(1, "2012-12-13"); if (counter.counter != 3) return false;
    log(' '+9); counter.incr(1, "2012-12-13"); if (counter.counter != 4) return false;
    log(' '+10); counter.incr(1, "2012-12-13"); if (counter.counter != 4) return false;
    return true;
  },
  function() {
    var counter = new Counter(testConfig.check_in);
    log(' '+1); counter.incr(1, "2012-12-12"); if (counter.counter != 1) return false;
    log(' '+2); counter.incr(1, "2012-12-12"); if (counter.counter != 1) return false;
    log(' '+3); counter.incr(1, "2012-12-13"); if (counter.counter != 2) return false;
    log(' '+4); counter.incr(0, "2013-01-13"); if (counter.counter != 0) return false;
    log(' '+5); counter.incr(1, "2013-01-19"); if (counter.counter != 1) return false;
    return true;
  },
  function() {
    var counter = new Counter(testConfig.milionaire_goblin);
    log(' '+1); counter.incr(1, "2012-12-12"); if (counter.counter != 1) return false;
    log(' '+2); counter.incr(1, "2012-12-12"); if (counter.counter != 2) return false;
    log(' '+2); counter.incr(1, "2012-12-12"); if (counter.counter != 3) return false;
    log(' '+2); counter.incr(1, "2012-12-12"); if (counter.counter != 3) return false;
    log(' '+3); counter.incr(0, "2012-12-13"); if (counter.counter != 0) return false;
    log(' '+4); counter.incr(0, "2013-01-13"); if (counter.counter != 0) return false;
    log(' '+4); counter.incr(1, "2013-01-13"); if (counter.counter != 1) return false;
    return true;
  },
];

function runTest(e) {
  log(e.toString());
  return e();
}

for (var k in counterTests) {
  if ( !runTest( counterTests[k] )) {
    console.log("This test failed.");
    debug = true;
    runTest( counterTests[k] );
    break;
  }
}
