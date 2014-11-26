helper =  require('../../build/helper.js');
require('should');
 

describe('React', function () {
    function Item() { 
        this.count = 1;
        this.property = 3;
    }

    var testObject = { xp: 0, peed:0, property: { health: 1 }, item: [],vipItem:{count:1,property:{count:2}}};
    var anotherTestObject = {xp:0, property:{health:1},item:[]};
    var nestedObject = { object: testObject, objVersion: 5, item: [], };
    var version_config = {
        test: {
            basicVersion: ['xp', 'property'],
            itemVersion: ['item',]
        },
        item: ['count', 'property'],
        nest: {objVersion:['object@test'], dummyVersion: ['vipItem']}
    };

    setupVersionControl =  helper.addVersionControl(version_config);
    var basicVersion = 0;
    var itemVersion = 0;
    var objVersion = 5;
    var dummyVersion= 0;
    function checkVersion() {
        testObject.should.have.property('basicVersion').equal(basicVersion);
        testObject.should.have.property('itemVersion').equal(itemVersion);
        nestedObject.should.have.property('objVersion').equal(objVersion);
    }
	function pv() {
		console.log({
			basicVersion : basicVersion,
			itemVersion  : itemVersion ,
			objVersion   : objVersion  ,
		});
	}

    it('set up', function () {
        testObject = setupVersionControl(testObject, 'test');
        nestedObject = setupVersionControl(nestedObject, 'nest');
        anotherTestObject = setupVersionControl(anotherTestObject, 'nest');
        checkVersion();
    });
    

    it('basic change', function () {
        testObject.xp = 1; basicVersion += 1; objVersion += 1; checkVersion();
        testObject.property.health += 3; basicVersion += 1; objVersion += 1; checkVersion();
    });

    it('new property', function () {
        testObject.property.speed = 5; basicVersion += 1; objVersion += 1; checkVersion();
        testObject.power = 1024;  checkVersion();
        nestedObject.power = 1024;  checkVersion();
        nestedObject.vipItem = new Item(); dummyVersion += 1; checkVersion();
        nestedObject.vipItem.property = {}; dummyVersion += 1; checkVersion();
    });

    it('dont change', function () {
        testObject.xp = 1; checkVersion();
        testObject.xp = '1'; basicVersion += 1; objVersion += 1; checkVersion();
        testObject.xp = '1'; checkVersion();
    });

    it('new object property', function () {
        testObject.property.appearance = {hair:1}; basicVersion += 1; objVersion += 1; checkVersion();
        testObject.property.appearance = {hair:1}; basicVersion += 1; objVersion += 1; checkVersion();
        testObject.property.appearance.hair += 1; basicVersion += 1; objVersion += 1; checkVersion();
    });

    it('observe', function () {
        var xpVersion = 0;
        testObject.observe('xp', function () { xpVersion += 1});
        testObject.xp += 1; 
        basicVersion += 1; objVersion += 1; checkVersion();
        xpVersion.should.equal(1);
    });

    it('this observer should fail', function () {
        try {
            testObject.observe('xp', 'function_that_not_exist');
            throw "Why don't you fail";
        } catch (e) {
            e.should.not.equal("Why don't you fail");
        }

        try {
            testObject.observe('key_that_not_exist', console.log);
            throw "Why don't you fail";
        } catch (e) {
            e.should.not.equal("Why don't you fail");
        }
    });

    it('array', function () {

        nestedObject.item.push(testObject.vipItem); checkVersion();
        testObject.item.push(testObject.vipItem); itemVersion += 1; objVersion += 1; checkVersion();
        testObject.item.push(new Item()); itemVersion += 1; objVersion += 1; checkVersion();
        testObject.item[5] = new Item(); itemVersion += 1; objVersion += 1; checkVersion();
        testObject.item.pop(); itemVersion += 1; objVersion += 1; checkVersion();
        testObject.vipItem.property.count = 5;
        itemVersion += 1;  objVersion += 1; checkVersion();
    });

    it('combo', function () {
    });

//    it('array print', function() {
//        var arr = testObject.item;
//        for(var i =0; i< arr.length; i++){
//            console.log('fv', i, arr[i]);
//        }
//        for (idx in arr){
//            console.log('fi',idx, arr[idx]);
//        }
//        console.log('print', arr);
//    });
//    it('json', function() {
//        console.log(JSON.stringify(testObject));
//    });

    it('????', function() {
        
        nestedObject.object = anotherTestObject;
    });



//    it('tell me what has changed', function () {
//        testObject.getChangedInfo();
//        testObject.xp = 5;
//        testObject.getChangedInfo().should.equal({xp:5});
//        testObject.getChangedInfo().should.equal({});
//
//        testObject.item[0].property.count = 10;
//        testObject.xp = 6;
//        testObject.getChangedInfo().should.equal({xp:5, item: {0:{property:{count:10}}}});
//        nestedObject.getChangedInfo().should.equal({vipItem: {property:{count:10}}});
//    });
});
