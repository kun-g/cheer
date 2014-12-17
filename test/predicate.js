var libTrigger = require('../js/trigger');
Condition = libTrigger.Condition;
Action = libTrigger.Action;
Query = libTrigger.Query;
executeSequal = libTrigger.executeSequal;
require('should');

var obj = { name : 'Before', health: 0, isAlive: function () { return this.health>0; } };

describe('Sequal', function () {
    describe('Mechanism', function () {
        it('SimpleQuery', function () {
            var obj = {count: 5};
            var key = ["count"];
            var variables = { obj: obj, key: key };
            executeSequal({query: 'get_property', object: obj, key: "count"}).should.equal(5);
            executeSequal({
                query: 'get_property',
                object: "$obj",
                key: "count"
            }, variables).should.equal(5);
            executeSequal({
                query: 'get_property',
                object: obj,
                key: "$key.0"
            }, variables).should.equal(5);
            executeSequal({
                query: 'get_property',
                object: obj,
                key: {query: 'get_property', object: "$key", key: "0"}
            }, variables).should.equal(5);
        });
    });
    describe('Queries', function () {
        it('get_property', function () {
            obj.property = {attack:1, defence:2};
            var query = new Query('get_property');
            query.evaluate(obj, 'health').should.equal(0);
            query.evaluate(obj, 'property.attack').should.equal(1);

            var keys = ['attack', 'defence'];
            query.evaluate(query.evaluate(obj, 'property'), query.evaluate(keys, 0)).should.equal(1);
            query.evaluate(query.evaluate(obj, 'property'), query.evaluate(keys, 1)).should.equal(2);
        });
    });
});

describe('Condition', function () {
    it('Alive', function () {
        var condition = new Condition({predicate: 'alive'});
        obj.health = 1; condition.evaluate({object: obj}).should.equal(true);
        obj.health = 0; condition.evaluate({object: obj}).should.equal(false);
    });

    it('Mathmatical Compare', function () {
        var biggerThanOne = new Condition({predicate: '>', value2: 1});
        biggerThanOne.evaluate({value1: 0}).should.equal(false);
        biggerThanOne.evaluate({value1: 2}).should.equal(true);
        biggerThanOne.evaluate({value1: 2, value2: 0}).should.equal(true);
    });

    it('Logic operation', function () {
        var cTrue = {predicate: ">", value1: 1, value2: 0};
        var cFalse = {predicate: "=", value1: 2, value2: 1};
        var trueANDfalse1 = [cTrue, cFalse];
        var trueANDfalse2 = {and: [cTrue, cFalse]};
        var trueORfalse = {or: [cTrue, cFalse]};
        var NOTtrueORfalse = {not: trueORfalse};

        (new Condition(cTrue)).evaluate().should.equal(true);
        (new Condition(cFalse)).evaluate().should.equal(false);
        (new Condition(trueANDfalse1)).evaluate().should.equal(false);
        (new Condition(trueANDfalse2)).evaluate().should.equal(false);
        (new Condition(trueORfalse)).evaluate().should.equal(true);
        (new Condition(NOTtrueORfalse)).evaluate().should.equal(false);
    });

    it('Composed', function () {
        var config = {
            predicate: '=',
            value1: { query: 'get_property', object: '$Sender', key: 'health' },
            value2: 1
        };
        var condition = new Condition(config);
        condition.addVariable('Sender', {health: 1}).evaluate().should.equal(true);
        condition.addVariable('Sender', {health: 0}).evaluate().should.equal(false);
    });
});

describe('Action', function () {
    it('modify_property', function () {
        var action = new Action({action: 'modify_property', key: 'name', value: 'Object'});
        action.execute({object: obj});
        obj.name.should.equal('Object');
    });

    it('Curring', function () {
        var action = new Action({action: 'modify_property', key: 'name'});
        action.execute({value: 'Dummy', object: obj});
        obj.name.should.equal('Dummy');

        var changeName = new Action({action: 'modify_property', object: obj, key: 'name'});
        changeName.execute({value: 'Before'});
        obj.name.should.equal('Before');
    });
});

describe('Trigger', function () {
    var triggers = {
        modNameWhenAlive : {
            condition: [{predicate: 'alive'}],
            action: { action: 'modify_property', key: 'name', value: 'After' }
        },
        resurrect : {
            condition: {not: {predicate:'alive'}},
            action: { action: 'modify_property', key: 'health', value: 20}
        },

        //randActionWhenAlive : {
        //    condition: 'alive',
        //    action: [
        //      { weight: 1, action: 'return 1' },
        //      { weight: 1, action: 'return 2' },
        //      { weight: 1, action: 'return 3' }
        //    ]
        //},
        //complex: {
        //    condition: 'alive',
        //    action: {
        //        type: 'set',
        //        actions: [
        //          { condition: 1, action: 'return 1' },
        //          { condition: 2, action: 'return 2' },
        //          { action: 'return 3' } // default
        //        ]
        //    }
        //},
        //sequence: {
        //    condition: 'alive',
        //    action: {
        //        type: 'sequence', // default
        //        actions: [
        //          { condition: 1, action: 'return 1' },
        //          { condition: 2, action: 'return 2' },
        //          { action: 'return 3' } // always
        //        ]
        //    }
        //},
        //set_if_not_have: { },
        //decrease_value: { },
        //setUpCountDown: {
        //    condition: { not: { predicate: 'have_property', object: '$Sender', key: '$Key' } },
        //    action: [ { action: 'modify_property', key: '$Key', value: '$InitialValue' }]
        //},
        //countDown : { // key, count, event, action
        //    action: [
        //    {
        //        action: 'modify_property',
        //        key: '$Key',
        //        value: {
        //            query: 'get_property', object: '$ThisSpell', key: '$Key'
        //        }
        //    }]
        //},
        //countDownCheck : { // key, count, event, action
        //    condition: {
        //        predicate: '=',
        //        value1: 0,
        //        value2: { query: 'get_property', object: '$ThisSpell', key: '$Key'}
        //    },
        //    action: [{ }]
        //},
    };

    it('Basic', function () {
        var preName = obj.name;
        var modNameWhenAlive = new libTrigger.Trigger(triggers.modNameWhenAlive);
        modNameWhenAlive.execute({object: obj});
        obj.name.should.equal(preName);

        var resurrect = new libTrigger.Trigger(triggers.resurrect);
        resurrect.execute({object: obj});
        modNameWhenAlive.execute({object: obj});
        obj.name.should.equal('After');
    });
});
