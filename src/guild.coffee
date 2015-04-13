{implementing} = require('./helper')
{Serializer, registerConstructor} = require './serializer'
{DBWrapper } = require './dbWrapper'

class Upgradeable extends Serializer
  constructor: (data) ->
    cfg ={
      level:0
    }
    super(data,cfg,{})

  upgrade: (oprator,args) ->
    return {ret:RET_Not_Upgradeable} unless @canUpgrade(oprator,args)

  currentLevel:(level) ->
    if level?
      @setter(level)
    else
      @getter()

  upgradeCost: (level) ->

  canUpgrade: (oprator,args) -> true

Modifier = implementing(Serializer, Upgradeable, class _Modifier
  constructor: (data) ->
    super(data,{},{})

  active: (oprator) ->

  applyModifier: (args) ->

  #override 
  canUpgrade: () ->
  claimActiveCost: () ->
)

class AppendGoldModifier extends Modifier
  constructor: () ->
    cfg = {
      type:'+gold'
    }
    super()
  exec: (args) ->

class Building
  constructor: () ->
    cfg = {
        modifierLst:[]
    }
  getModifierByType: (type) ->
Guild = implementing(Serializer, Upgradeable, class _Guild
  constructor: (data) ->
    cfg ={
      building: Building
      shop: Shop
    }
    super({
      Upgradeable:{getter:'getter', setter:'setter'},
      Serializer: [data, cfg,{}]
    })
  queryInfo: (type) ->
  test: () ->
    console.log('test',@getter, @setter)
    @s()

)

class GuildManager extends DBWrapper
  constructor: (data) ->
    cfg ={
      guildLst:[],
    }
    super(data,cfg, {})

  createGuild: (player) ->
  joinGuild: (player) ->
  invitePlayer: (master, player) ->
  destroyGuild: (player) ->


guild = new Guild()
guild.test()
