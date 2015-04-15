###
shall = require('should')
libVersion = require('../js/versionManager')
describe 'VersionManager', ->
  basePath = 'test/VersionManagerTest/'
  searchPath = basePath + 'update/'
  masterPath = basePath + 'base/'
  subPath = searchPath + ''
  derivedPath = searchPath + 'test/'
  fileUtil = loadJSON: (path, cb) ->
    fs = require('fs')
    fs.readFile path, (err, data) ->
      if err
        console.log 'LoadFileFail', path
      cb null, JSON.parse(data)
      return
    return
  libVersion.setFileUtil fileUtil

  createManager = ->
    manager = new (libVersion.VersionManager)
    manager.setRootPath masterPath
    manager.setSearchPath searchPath
    manager

  masterConfig = 
    '0':
      'branch': 'master'
      'version': '0'
      'path': masterPath
      'files': [
        'a.js'
        'dir/a.js'
      ]
    '1':
      'branch': 'master'
      'version': '1'
      'path': subPath + '1/'
      'prevVersion': '0'
      'files': [
        'b.js'
        'dir/b.js'
        'dir/a.js'
      ]
    '2':
      'branch': 'master'
      'version': '2'
      'path': subPath + '2/'
      'prevVersion': '1'
      'files': [
        'c.js'
        'dir/b.js'
      ]
  tests = [
    {
      version: 0
      config: masterConfig
      branch: 'master'
      result:
        'a.js': masterPath + 'a.js'
        'dir/a.js': masterPath + 'dir/a.js'
    }
    {
      version: 1
      config: masterConfig
      branch: 'master'
      result:
        'a.js': masterPath + 'a.js'
        'b.js': subPath + '1/' + 'b.js'
        'dir/a.js': subPath + '1/' + 'dir/a.js'
        'dir/b.js': subPath + '1/' + 'dir/b.js'
    }
    {
      version: 2
      config: masterConfig
      branch: 'master'
      result:
        'a.js': masterPath + 'a.js'
        'b.js': subPath + '1/' + 'b.js'
        'c.js': subPath + '2/' + 'c.js'
        'dir/a.js': subPath + '1/' + 'dir/a.js'
        'dir/b.js': subPath + '2/' + 'dir/b.js'
    }
  ]
  it 'init', (done) ->
    manager = createManager()
    manager.init 2, (err) ->
      shall(manager.getVersion(0)).eql tests[0].result
      shall(manager.getVersion(1)).eql tests[1].result
      shall(manager.getVersion(2)).eql tests[2].result
      shall(manager.getVersion(1)).eql tests[1].result
      shall(manager.getChangeList('0', '2')).eql masterConfig[2].files.concat(masterConfig[1].files)
      done err
      return
    return
  return
###
