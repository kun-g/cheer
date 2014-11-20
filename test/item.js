var shall = require('should');
var createItem = require('../js/item').createItem;

describe('Item', function () {
  describe('Equipment', function () {
      var Enhance_Stone = require('../js/item').Enhance_Stone;
      it('Combine', function () {
          var gemConfig = {
              command: [
                  { type: 'incress_property', property: { attack: 10 } },
                  { type: 'change_appearance', appearance: {id: 3, particle: 4} } ,
                  { type: 'install_skill', id: 1, level: 1 } ,
              ],
              getInitialData: function () { return gemConfig; }
          };
          var gem = new Enhance_Stone(gemConfig);
          var sword = createItem({
              category: 1,
              basic_properties: {
                  attack: 20,
                  strength: 10
              },
              effectf: {id: 1},
              effectm: {id: 2}
          });
          sword.executeCommand('update_appearance', {gender: 1});
          sword.appearance().should.eql({id:2});
          sword.installEnhancement(gem);
          sword.property().should.eql({attack: 30, strength: 10});
          sword.skill.should.eql([{id:1, level:1}]);
          sword.appearance().should.eql({id:3, particle: 4});
      });
      it('Serialization', function () {
      });
  });
});
