var triggerLib = require('../js/trigger');
require("../js/define");
var shall = require('should');
describe('', function () {

    it('direction', function() {

        var calcDirection = triggerLib.calcDirection;
        var translatePos = triggerLib.translatePos;
        var data = [
        {psrc:12, ptar: [0,6], res: 7},
        {psrc:12, ptar: [7,2],res: 8},
        {psrc:12, ptar: [8,4],res: 9},
        {psrc:12, ptar: [13,14], res: 6},
        {psrc:12, ptar: [18,24], res: 3},
        {psrc:12, ptar: [17,22], res: 2},
        {psrc:12, ptar: [16,20], res: 1},
        {psrc:12, ptar: [12], res: 5},
        {psrc:1, ptar: [22,21,20], res: 2},
        {psrc:20, ptar: [0,1], res: 8},
        {psrc:12, ptar: [10,11], res: 4},
        ];
        
        for (var i in data) {
            cfg  = data[i];
            cfg.ptar.forEach(function(ptar) {
                var res = calcDirection(translatePos(cfg.psrc), translatePos(ptar));
                res.should.equal(cfg.res);
            });
        }
    });
describe('Filter object', function () {
function alive() { return this.health > 0; }
var objects = [
  {name: 'o1', roleID: 1, health: 10, faction: 0, isAlive: alive, pos: 0},
  {name: 'o2', roleID: 2, health: 11, faction: 1, isAlive: alive, pos: 1},
  {name: 'o3', roleID: 3, health: 12, faction: 2, isAlive: alive, pos: 2},
  {name: 'o4', roleID: 4, health: 13, faction: 3, isAlive: alive, pos: 3}
];
var factionDB = {
  0: {
       1: {attackable: true},
       3: {attackable: true},
     }
};
var fo = triggerLib.filterObject;
var areaShape = triggerLib.areaShape;
var direction = triggerLib.direction;
var blocks;
var variable = {};
var env = {
  getFactionConfig: function (src, tar, flag) {
                      if (factionDB[src] == null || factionDB[src][tar] == null) return false;
                      return factionDB[src][tar];
                    },
  getBlock: function (index) {
      return blocks[index];
  },
  variable: function() {
      return variable;
  }
};
var testThis = function (filters, names) {
  fo({}, objects, filters, env).map(function (e) { return e.name; }).should.eql(names);
};
describe("Role", function () {
    it('same-faction', function () {
        testThis({type: 'same-faction', faction: 0}, ['o1']);
    });
    it('different-faction', function () {
        testThis({type: 'different-faction', faction: 0}, ['o2', 'o3', 'o4']); 
    });
    it('target-faction-with-flag', function () {
        testThis({type:'target-faction-with-flag', faction:0, flag:"attackable"}, ['o2', 'o4']); 
    });
    it('target-faction-without-flag', function () {
        testThis({type:'target-faction-without-flag', faction:0, flag:"attackable"}, ['o1','o3']);
    });
    it('source-faction-with-flag', function () {
        testThis({type: 'source-faction-with-flag', faction: 3, flag: "attackable"}, ['o1']); 
    });
    it('source-faction-without-flag', function () {
        testThis(
            {type: 'source-faction-without-flag', faction: 3, flag: "attackable"},
            ['o2', 'o3', 'o4']
            ); 
    });
    it('role-id', function () { testThis({type: 'role-id', roleID: 1}, ['o1']); });
    it('alive', function () { testThis({type: 'alive'}, ['o1', 'o2', 'o3', 'o4']); });
    it('sort', function () {
        testThis({type: 'sort', by: 'health', reverse: true}, ['o4', 'o3', 'o2', 'o1']);
    });
    it('count', function () {
        testThis({type: 'count', count: 3}, ['o1', 'o2', 'o3']);
    });
    it('anchor', function () {
        var opt = {type: 'anchor', anchorPos:[17], shape: areaShape.Line, startDistance: 1, length: 3};
        opt.direction = direction.North;
        testThis(opt, ['o3']);
    });
});
describe("anchor", function () {
    function resetPlayground() {
        blocks = [];
        for (var i = 0; i < Dungeon_Height; i++) {
            for (var j = 0; j < Dungeon_Width; j++) {
                blocks[i*Dungeon_Width+j] = {
                    name: "x:"+j+", y:"+i,
                    pos: i*Dungeon_Width+j,
                    isBlock: true
                };
            }
        }
    }
    resetPlayground();

    var testThis = function (filters, names) {
      fo({}, blocks, filters, env).map(function (e) { return e.name; }).should.eql(names);
    };
    it('Line', function () {
        var opt = {type: 'anchor', anchorPos:[17], shape: areaShape.Line, startDistance: 1, length: 3};
        testThis( opt, ['x:3, y:3', 'x:4, y:3']);
        opt.direction = direction.NorthEast;
        testThis( opt, ['x:4, y:1', 'x:3, y:2']);
        opt.direction = direction.South;
        testThis( opt, ['x:2, y:4', 'x:2, y:5']);
        opt.direction = direction.NorthWest;
        testThis( opt, ['x:0, y:1', 'x:1, y:2' ]);
    });
    it('Cross', function () {
        var opt = {type: 'anchor', anchorPos:[17], shape: areaShape.Cross, startDistance: 0, length: 2};
        testThis( opt, [
                        'x:2, y:1',
                        'x:2, y:2',
'x:0, y:3', 'x:1, y:3', 'x:2, y:3', 'x:3, y:3', 'x:4, y:3',
                        'x:2, y:4',
                        'x:2, y:5',
        ]);
    });
    it('Square', function () {
        var opt = {type: 'anchor', anchorPos:[17], shape: areaShape.Square, startDistance: 0, length: 3};
        testThis( opt, [
            'x:0, y:0', 'x:1, y:0', 'x:2, y:0', 'x:3, y:0', 'x:4, y:0',
            'x:0, y:1', 'x:1, y:1', 'x:2, y:1', 'x:3, y:1', 'x:4, y:1',
            'x:0, y:2', 'x:1, y:2', 'x:2, y:2', 'x:3, y:2', 'x:4, y:2',
            'x:0, y:3', 'x:1, y:3', 'x:2, y:3', 'x:3, y:3', 'x:4, y:3',
            'x:0, y:4', 'x:1, y:4', 'x:2, y:4', 'x:3, y:4', 'x:4, y:4',
            'x:0, y:5', 'x:1, y:5', 'x:2, y:5', 'x:3, y:5', 'x:4, y:5'
        ]);
    });
    it('Triangle', function () {
        var opt = {type: 'anchor',  anchorPos:[10], shape: areaShape.Triangle, startDistance: 0, length: 3};
        testThis( opt, [
                                    'x:2, y:0',
                        'x:1, y:1', 'x:2, y:1',
            'x:0, y:2', 'x:1, y:2', 'x:2, y:2',
                        'x:1, y:3', 'x:2, y:3',
                                    'x:2, y:4'
        ]);
    });
    it('Triangle', function () {
        var opt = {type: 'anchor',  anchorPos:[19], direction: 7, shape: areaShape.Triangle, startDistance: 0, length: 3};
        testThis( opt, [
                                    'x:4, y:1',
                        'x:3, y:2', 'x:4, y:2',
            'x:2, y:3', 'x:3, y:3', 'x:4, y:3' 
        ]);
    });


});
});

  var obj = {
    name: 'Ken',
    birth: {
      year: 1234,
      month: 3,
      day: 2
    },
    proglan: [
      {name: 'C', years: 11},
      {name: 'C++', years: 10},
      {name: 'ASM', years: 12},
      {name: 'JS', years: 2},
      {name: 'Lisp', years: 2}
    ]
  };
  describe('Conditions', function () {
    conditionCheck = triggerLib.parse;
    it('Should deal with and or not > >= < <= == !=', function () {
      var trues = [{"==": [1, 1]}, {"!=": [0, 1]}, {">": [5, 1]}, {">=": [5, 1]},
                   {">=": [5, 5]}, {"<=": [5, 5]}, {"<=": [5, 5.5]}, {"<": [5, 5.5]},
                  true];
      var falses = [{"==": [0, 1]}, {"!=": [1, 1]}, {">": [1, 5]}, {">=": [1, 8]},
                    {"<=": [5.5, 5]}, {"<": [5.6, 5.5]}, false];
      var k;
      for (k in trues) {
        conditionCheck(trues[k]).should.equal(true);
        conditionCheck({"not": trues[k]}).should.equal(false);
      }
      for (k in falses) {
        conditionCheck(falses[k]).should.equal(false);
        conditionCheck({"not": falses[k]}).should.equal(true);
      }
      conditionCheck({"and": trues}).should.equal(true);
      conditionCheck({"or": trues}).should.equal(true);
      conditionCheck({"and": trues.concat(falses)}).should.equal(false);
      conditionCheck({"or": trues.concat(falses)}).should.equal(true);
    });
    it('Should work with variable', function (done) {
      var formulars = [{"==": ["v_var1", "v_var2"]}, {">=": ["v_var1", "v_var2"]},
                       {"<=": ["v_var1", "v_var2"]}, {"<=": ["v_var1", 1]}];
      var variables = {"v_var1": 1, "v_var2": 1};
      for (var k in formulars) {
        conditionCheck(formulars[k], variables).should.equal(true);
      }
      var formular = {"and": ["v_var1", "v_var2", "v_var3"]};
      variables = {"v_var1": true, "v_var2": true, "v_var3": true};
      conditionCheck(formular, variables).should.equal(true);
      formular = {"and": "v_var1"};
      variables = {"v_var1": [true, true, true, true]};
      conditionCheck(formular, variables).should.equal(true);
      done();
    });
    it('should pass doGetProperty', function () {
      var tests = [
        { key: "name", result: 'Ken' },
        { key: "birth.year", result: 1234 },
        { key: "proglan.2.name", result: "ASM" },
        { key: "proglan.2.years", result: 12},
        { key: "proglan.9.years", result: undefined},
      ];
      tests.forEach( function (t) {
        shall(triggerLib.doGetProperty(obj, t.key)).equal(t.result);
      });
    });
    it('should pass', function () {
      var cond1 = { "and": [
        { "==": [ { "type": "getProperty", "key": "stage.0.state"}, 2 ] }
      ]};
      var cond2 = { "and": [
        { "==": [ { "type": "getProperty", "key": "name"}, 'Ken' ] }
      ]};
      var tests = [ { cond: cond1, result: false}, { cond: cond2, result: true} ];
      tests.forEach( function (t) {
        shall(triggerLib.parse(t.cond, obj)).equal(t.result);
      });
    });
  });
  describe('Variable', function () {
    var bind = triggerLib.parse;
    it('Should work', function (done) {
      bind({v_var1: 1, v_var2: 2, v_var3: {'and': [true, false]}}).should.eql({v_var1: 1, v_var2: 2, v_var3:false});
      done();
    });
  });
  describe('Calculation', function () {
    var calculate = triggerLib.parse;
    it('Should work', function (done) {
      calculate({'+': [
          {'-': [
            {'*': [5, 2]}, 
            {"/": [8, 2]}
          ]}, 
          3
        ]}).should.equal(9);
      calculate({'&': [{'|': [{'~': 3}, 2]}, 2]}).should.equal(2);
      done();
    });
  });
  describe('Action', function () {
    doAction = triggerLib.parse;
    it('Should work with variables', function (done) {
      var v = {v_test: 123};
      doAction([{type: 'deleteVariable', name: 'v_test'}], v);
      v.should.eql({});
      doAction([{type: 'newVariable', name: 'v_test', value: 123}], v);
      v.should.eql({v_test: 123});
      doAction([{type: 'modifyVariable', name: 'v_test', value: 321}], v);
      v.should.eql({v_test: 321});
      done();
    });
  });
  describe('Control flow', function () {
    var parse = triggerLib.parse;
    it('Branch', function (done) {
      var v = {v_i: 1};
      parse({
        if: {type: 'newVariable', name: 'v_test', value: 1},
        condition: {'>': [1, 2]},
        else: [
          {
            while: {type: 'modifyVariable', name: 'v_i', value: {'+': [1, 'v_i']}},
            condition: {'<': ['v_i', 3]}
      /*
       * [ { v_i: { '$lt': 3 } } ]
       */
          },
          {
            if: {type: 'newVariable', name: 'v_test', value: 2},
            condition: {'==': ['v_i', 3]}
          }
        ]}, v);
      v.should.eql({v_i: 3, v_test: 2});
      done();
    });
  });

  describe('TriggerManager', function () {
    var parse = triggerLib.parse;
    var tm = triggerLib.TriggerManager;
    var triggersConf = {
      "test": {
        "description": "测试",
        "triggerEvent": ["onTestEvent"],
        "action": [{"type": "newVariable", "name": "v_flag", "value": true}]
      },
      "test1": {
        "description": "测试",
        "variable": {"v_flag": false},
        "triggerEvent": ["onTestEvent"],
        "condition": { "and": [ "v_flag" ] },
        "action": [{"type": "newVariable", "name": "v_done", "value": true}]
      },
      "test2": {
        "action": [
          {
            "type": "modifyVariable",
            "name": "v_flag",
            "value": true,
            "trigger": "test1"
          }
        ]
      },
      "test3": {
        "variable": {"v_count": 0},
        "triggerEvent": ["onTestEvent"],
        "action": [
          {
            "type": "modifyVariable",
            "name": "v_count",
            "value": {"+": ["v_count", 1]}
          }
        ]
      }
    };
    tm = new tm(triggersConf);
    var tmCmd = {
      getEnvironment: function() { return tm; }
    };

    it('Install and Remove', function (done) {
      parse({type: 'installTrigger', name: 'test'}, {}, tmCmd);
      tm.triggers.should.have.property('test');
      parse({type: 'removeTrigger', name: 'test'}, {}, tmCmd);
      tm.triggers.should.not.have.property('test');
      done();
    });
    it('on event', function (done) {
      parse({type: 'installTrigger', name: 'test3'}, {}, tmCmd);
      tm.getTrigger('test3').variables.v_count.should.equal(0);
      tm.onEvent('onTestEvent', tmCmd);
      tm.getTrigger('test3').variables.v_count.should.equal(1);
      done();
    });
    it('Enable, disable and invoke', function (done) {
      parse({type: 'installTrigger', name: 'test3'}, {}, tmCmd);
      tm.getTrigger('test3').variables.v_count.should.equal(0);
      tm.invokeTrigger('test3');
      tm.getTrigger('test3').variables.v_count.should.equal(1);
      tm.disableTrigger('test3');
      tm.invokeTrigger('test3');
      tm.getTrigger('test3').variables.v_count.should.equal(1);
      tm.enableTrigger('test3');
      tm.invokeTrigger('test3');
      tm.getTrigger('test3').variables.v_count.should.equal(2);
      done();
    });
    it('Invoke, condition and modify variable', function (done) {
      parse({type: 'installTrigger', name: 'test1'}, {}, tmCmd);
      parse({type: 'installTrigger', name: 'test2'}, {}, tmCmd);
      tm.getTrigger('test1').variables.should.not.have.property('v_done');
      tm.invokeTrigger('test1', {}, tmCmd);
      tm.getTrigger('test1').variables.should.not.have.property('v_done');
      tm.invokeTrigger('test2', {}, tmCmd);
      tm.invokeTrigger('test1', {}, tmCmd);
      tm.getTrigger('test1').variables.should.have.property('v_done');
      done();
    });
  });
});
