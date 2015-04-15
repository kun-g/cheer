#spellLib = require('../js/spell');
describe 'Battle', ->
  describe 'Spell', ->
    it 'Install spell', ->
      #          var hero = new spellLib.Wizard();
      #          var spellConfig = {};
      #          hero.installSpell(spellConfig);
      #          hero.hasSpell().should.equal(true);
      return
    return
  describe 'AOE', ->
    # number board style
    modifier = 
      7:
        x: -1
        y: 1
      8:
        x: 0
        y: 1
      9:
        x: 1
        y: 1
      4:
        x: -1
        y: 0
      5:
        x: 0
        y: 0
      6:
        x: 1
        y: 0
      1:
        x: -1
        y: -1
      2:
        x: 0
        y: -1
      3:
        x: 1
        y: -1

    generatePlayground = ->
      ground = []
      i = 0
      while i < 11
        ground[i] = []
        j = 0
        while j < 11
          ground[i][j] = '口'
          j++
        i++
      ground[5][5] = '我'
      ground

    print = (ground) ->
      i = ground.length - 1
      while i >= 0
        row = ground[i]
        str = ''
        for j of row
          str += row[j]
        console.log str
        i--
      return

    setBlock = (ground, x, y) ->
      if ground[y] and ground[y][x]
        ground[y][x] = '回'
      return

    selectLine = (x, y, direction, dFrom, length, ground) ->
      mod = modifier[direction]
      i = dFrom
      while i < dFrom + length
        setBlock ground, x + mod.x * i, y + mod.y * i
        i++
      return

    selectCross = (x, y, direction, dFrom, length, ground) ->
      selector = [
        2
        4
        6
        8
      ]
      if direction % 2
        selector = [
          1
          3
          7
          9
        ]
      for j of selector
        selectLine x, y, selector[j], dFrom, length, ground
      return

    selectSquare = (x, y, direction, dFrom, length, ground) ->
      mode = undefined
      selector = undefined
      adjust = 1
      if direction % 2
        selector = [
          [
            8
            3
          ]
          [
            6
            1
          ]
          [
            2
            7
          ]
          [
            4
            9
          ]
        ]
      else
        selector = [
          [
            7
            6
          ]
          [
            9
            2
          ]
          [
            1
            8
          ]
          [
            3
            4
          ]
        ]
        adjust = 2
      i = dFrom
      while i < dFrom + length
        for j of selector
          mod = modifier[selector[j][0]]
          selectLine x + mod.x * i, y + mod.y * i, selector[j][1], 0, i * adjust + 1, ground
        i++
      return

    selectTriangle = (x, y, direction, dFrom, length, ground) ->
      localModifier = 
        7: [
          4
          9
        ]
        8: [
          7
          6
        ]
        9: [
          8
          3
        ]
        4: [
          1
          8
        ]
        5: [
          5
          5
        ]
        6: [
          9
          2
        ]
        1: [
          2
          7
        ]
        2: [
          3
          4
        ]
        3: [
          6
          1
        ]
      i = dFrom
      while i < dFrom + length
        mod = localModifier[direction][0]
        mod = modifier[mod]
        if direction % 2
          selectLine x + mod.x * i, y + mod.y * i, localModifier[direction][1], 0, i + 1, ground
        else
          selectLine x + mod.x * i, y + mod.y * i, localModifier[direction][1], 0, 1 + 2 * i, ground
        i++
      return

    it 'Ground', ->
      #var ground = generatePlayground(); selectLine(5, 5, 1, 3, 3, ground); print(ground);
      #var ground = generatePlayground(); selectCross(5, 5, 6, 3, 5, ground); print(ground);
      #var ground = generatePlayground(); selectSquare(5, 5, 6, 1, 2, ground); print(ground);
      #var ground = generatePlayground(); selectSquare(5, 5, 6, 0, 3, ground); print(ground);
      #var ground = generatePlayground(); selectTriangle(0, 2, 6, 0, 3, ground); print(ground);
      #var ground = generatePlayground(); selectTriangle(5, 5, 3, 1, 2, ground); print(ground);
      #var ground = generatePlayground(); selectTriangle(5, 5, 2, 1, 2, ground); print(ground);
      return
    return
  return
