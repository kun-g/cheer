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
    cost =  @upgradeCost(@level)
    return {ret:RET_Not_Upgradeable} unless cost?
    ntf = oprator.claimCost(cost)
    if ntf?
      level += 1
    return ntf

  currentLevel:() ->
    @level


  #override
  upgradeCost: (level) ->  null
  canUpgrade: (oprator,args) -> true

Modifier = implementing(Serializer, Upgradeable, class _Modifier
  constructor: (data) ->
    cfg ={
      type:''
      activeTimeStamp:0
    }
    super({
      Upgradeable:{getter:'getter', setter:'setter'},
      Serializer: [data, cfg,{}]
    })
 

  getConfig: (key) ->
    queryTable(TABLE_GUILD,'modifier')?[@type]

  active: (oprator) ->

  _isActive = () ->
    if verify(helperLib.currentTime(), @getConfig('active').stayOpen, {})
      return true
  applyModifier: (event, target) ->
    if @active._isActive()
      1

  claimActiveCost: () ->

  #override Upgradeable
  upgradeCost: (level) ->
    @getConfig('upgradeCost')?[@currentLevel()]

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
