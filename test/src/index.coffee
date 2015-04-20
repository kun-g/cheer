{initVipConfig} = require('../js/define')
require('should')

describe 'initVipConfig', ->
  checkdata = [
    {},
    {'bothIn 1 and 2':1, 'only in 1':2},
    {'bothIn 1 and 2':2, 'only in 1':2,'only in 2':3}
  ]
  cfg = {
    "VIP": {
      "requirement": [
        {
            "rmb": 0
            "privilege":[]
        },
        {
            "rmb": 30,
            "privilege":[
                {
                    "name":"bothIn 1 and 2",
                    "data":1
                },
                {
                    "name":"only in 1",
                    "data":2
                },
            ]
        },
        {
            "rmb": 100,
            "privilege":[
                {
                    "name":"bothIn 1 and 2",
                    "data":2
                },
                {
                    "name":"only in 2",
                    "data":3
                }
            ]
        }
      ],
      level:[
        { "desc":"0"},
        { "desc":"1"},
        { "desc":"2"},
     
      ]
    },
    "VIP2": {
      "requirement": [
        {
            "rmb": 0
            "privilege":[]
        },
        {
            "rmb": 30,
            "privilege":[
                {
                    "name":"bothIn 1 and 2",
                    "data":1
                },
                {
                    "name":"only in 1",
                    "data":2
                },
            ]
        },
        {
            "rmb": 100,
            "privilege":[
                {
                    "name":"bothIn 1 and 2",
                    "data":2
                },
                {
                    "name":"only in 2",
                    "data":3
                }
            ]
        }
      ],
      level:[
        { "desc":"0"},
        { "desc":"1"},
        { "desc":"2"},
      ]
    }
  }
   
  it '', (done) ->
    newCfg = initVipConfig(cfg)
    ['VIP','VIP2'].forEach((name) ->
      checkdata.forEach((chData,idx) ->
        newCfg[name].requirement[idx].privilege.forEach((dat) ->
          dat.data.should.equal(chData[dat.name])
        )
      )
    )
    done()



