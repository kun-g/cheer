var should = require('should');
var triggerLib = require('../trigger');
require('../globals');
initServer();
gServerName = 'UnitTest';
dbPrefix = gServerName+'.';

logLevel = 1;

describe('', function () {
  describe('Conditions', function () {
    conditionCheck = triggerLib.parse;
    it('Should deal with and or not > >= < <= == !=', function (done) {
      var trues = [{"==": [1, 1]}, {"!=": [0, 1]}, {">": [5, 1]}, {">=": [5, 1]}, 
                   {">=": [5, 5]}, {"<=": [5, 5]}, {"<=": [5, 5.5]}, {"<": [5, 5.5]},
                  true];
      var falses = [{"==": [0, 1]}, {"!=": [1, 1]}, {">": [1, 5]}, {">=": [1, 8]},
                    {"<=": [5.5, 5]}, {"<": [5.6, 5.5]}, false];
      for (var k in trues) {
        conditionCheck(trues[k]).should.equal(true);
        conditionCheck({"not": trues[k]}).should.equal(false);
      }
      for (var k in falses) {
        conditionCheck(falses[k]).should.equal(false);
        conditionCheck({"not": falses[k]}).should.equal(true);
      }
      conditionCheck({"and": trues}).should.equal(true);
      conditionCheck({"or": trues}).should.equal(true);
      conditionCheck({"and": trues.concat(falses)}).should.equal(false);
      conditionCheck({"or": trues.concat(falses)}).should.equal(true);
      done();
    });
    it('Should work with variable', function (done) {
      var formulars = [{"==": ["v_var1", "v_var2"]}, {">=": ["v_var1", "v_var2"]}, 
                       {"<=": ["v_var1", "v_var2"]}, {"<=": ["v_var1", 1]}];
      var variables = {"v_var1": 1, "v_var2": 1};
      for (var k in formulars) {
        conditionCheck(formulars[k], variables).should.equal(true);
      }
      var formular = {"and": ["v_var1", "v_var2", "v_var3"]};
      var variables = {"v_var1": true, "v_var2": true, "v_var3": true};
      conditionCheck(formular, variables).should.equal(true);
      formular = {"and": "v_var1"};
      variables = {"v_var1": [true, true, true, true]};
      conditionCheck(formular, variables).should.equal(true);
      done();
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
    tm = new tm();
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
