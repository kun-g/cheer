"use strict"
var conf = {
  A: {
    name: "A",
    speed: 5,
    strenth: 6,
    health: 20
  },
  B: {
    _inherit: "A",
    name: "B",
    speed: 7
  },
  C: {
    _inherit: "B",
    name: "C"
  },
  D: {
    _inherit: "E",
    name: "D"
  },
  E: {
    _inherit: "C",
    name: "E"
  }
};

function clone (obj) {
  var res = {};
  for (var k in obj) {
    var v = obj[k];
    if (typeof v == 'object') {
      v = clone(v);
    }
    res[k] = v;
  }
  return res;
}

function merge (to, from) {
  var res = clone(to);
  for (var k in from) {
    res[k] = from[k];
  }
  delete res._inherit;
  return res;
}

function compileTable(table) {
  var res = {};
  var pending = [];

  for (var key in table) {
    if (table[key]._inherit) {
      if (res[table[key]._inherit]) {
        res[key] = merge(res[table[key]._inherit], table[key]);
      } else {
        pending.push({
          value: table[key],
          key: key
        });
      }
    } else {
      res[key] = clone(table[key]);
    }
  }

  var length = pending.length;
  while (length > 0) {
    pending = pending.filter(function (e) {
      if (res[e.value._inherit]) {
        res[e.key] = merge(res[e.value._inherit], e.value);
        return false
      } else {
        return true;
      }
    });
    
    if (length == pending.length) {
      console.log("Error: loop detected.");
      pending.forEach(function (e) { console.log(e.key); });
      return null;
    }

    length = pending.length;
  }

  return res;
}

function showObject(obj) {
  console.log(JSON.stringify(obj, null, 2));
}


showObject(compileTable(conf));
