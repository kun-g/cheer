//var spellLib = require('../js/spell');

describe('Battle', function () {
    describe('Spell', function () {
        it('Install spell', function () {
//          var hero = new spellLib.Wizard();
//          var spellConfig = {};
//          hero.installSpell(spellConfig);
//          hero.hasSpell().should.equal(true);
        });
    });
    describe('AOE', function () {
        function generatePlayground() {
            var ground = [];
            for (var i = 0; i < 11; i++) {
                ground[i] = [];
                for (var j = 0; j < 11; j++) {
                    ground[i][j] = '口';
                }
            }
            ground[5][5] = '我';
            return ground;
        }
        function print(ground) {
            for (var i = ground.length-1; i >= 0; i--) {
                var row = ground[i];
                var str = "";
                for (var j in row) {
                    str += row[j];
                }
                console.log(str);
            }
        }

        // number board style
        var modifier = {
            7: { x:-1, y: 1 }, 8: { x: 0, y: 1 }, 9: { x: 1, y: 1 },
            4: { x:-1, y: 0 }, 5: { x: 0, y: 0 }, 6: { x: 1, y: 0 },
            1: { x:-1, y:-1 }, 2: { x: 0, y:-1 }, 3: { x: 1, y:-1 }
            };
        function setBlock(ground, x, y) { 
            if (ground[y] && ground[y][x]) ground[y][x] = "回";
        }
        function selectLine(x, y, direction, dFrom, length, ground) {
            var mod = modifier[direction];
            for (var i = dFrom; i < dFrom+length; i++) {
                setBlock(ground, x+mod.x*i, y+mod.y*i);
            }
        }
        function selectCross(x, y, direction, dFrom, length, ground) {
            var selector = [2, 4, 6, 8];
            if (direction%2) selector = [1, 3, 7, 9];
            for (var j in selector) {
                selectLine(x, y, selector[j], dFrom, length, ground);
            }
        }
        function selectSquare(x, y, direction, dFrom, length, ground) {
            var mode,selector, adjust = 1;
            if (direction%2) {
                selector = [[8,3], [6,1], [2,7], [4,9]];
            } else {
                selector = [[7,6], [9,2], [1,8], [3,4]];
                adjust = 2;
            }

            for (var i = dFrom; i < dFrom+length; i++) {
                for (var j in selector) {
                    mod = modifier[selector[j][0]];
                    selectLine(x+mod.x*i, y+mod.y*i, selector[j][1], 1, i*adjust, ground);
                }
            }
        }
        function selectTriangle(x, y, direction, dFrom, length, ground) {
            var localModifier = {
                7: [4,9], 8: [7,6], 9: [8,3],
                4: [1,8], 5: [5,5], 6: [9,2],
                1: [2,7], 2: [3,4], 3: [6,1]
            };
            for (var i = dFrom; i < dFrom+length; i++) {
                var mod = localModifier[direction][0];
                mod = modifier[mod];
                if (direction%2) {
                    selectLine(x+mod.x*i, y+mod.y*i, localModifier[direction][1], 0, i+1, ground);
                } else {
                    selectLine(x+mod.x*i, y+mod.y*i, localModifier[direction][1], 0, 1+2*i, ground);
                }
            }
        }

        it('Ground', function () {
            //var ground = generatePlayground(); selectLine(5, 5, 1, 3, 3, ground); print(ground);
            //var ground = generatePlayground(); selectCross(5, 5, 6, 3, 5, ground); print(ground);
            //var ground = generatePlayground(); selectSquare(5, 5, 6, 3, 2, ground); print(ground);
            //var ground = generatePlayground(); selectSquare(5, 5, 1, 3, 2, ground); print(ground);
            //var ground = generatePlayground(); selectTriangle(5, 5, 6, 1, 2, ground); print(ground);
            var ground = generatePlayground(); selectTriangle(5, 5, 6, 1, 2, ground); print(ground);
        });
    });
});

