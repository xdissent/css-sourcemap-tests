
fs = require 'fs'
path = require 'path'
sass = require 'node-sass'
jade = require 'jade'
Promise = require 'bluebird'
convert = require 'convert-source-map'

readFile = Promise.promisify fs.readFile
writeFile = Promise.promisify fs.writeFile

compileCss = (name) ->
  fileName = path.resolve __dirname, "#{name}.sass"
  new Promise (resolve, reject) ->
    sass.render
      file: fileName
      sourceMap: fileName
      sourceComments: false
      omitSourceMapUrl: true
      error: reject
      success: (css, map) ->
        # Fix sass sourcemaps...
        map = convert.fromJSON map
        map.setProperty 'file', fileName
        sources = []
        sourcesContent = []
        for source in map.getProperty 'sources'
          sourceFile = path.resolve path.dirname(fileName), source
          sources.push path.relative process.cwd(), sourceFile
          sourcesContent.push readFile(sourceFile).then (src) -> src.toString()
        resolve Promise.all(sourcesContent).then (sourcesContent) ->
          map.setProperty 'sources', sources
          map.setProperty 'sourcesContent', sourcesContent
          css = "#{css}\n#{map.toComment().replace /^\/\//, '/*'} */"
          writeFile(fileName.replace(/\.sass$/, '.css'), css).then -> css

compileHtml = (locals = {}) ->
  new Promise (resolve, reject) ->
    fileName = path.resolve __dirname, 'index.jade'
    readFile(fileName).then (src) ->
      compiled = jade.compile src, filename: fileName
      html = compiled locals
      writeFile(fileName.replace(/\.jade$/, '.html'), html).then -> html

dataUri = (css) -> "data:text/css;base64,#{new Buffer(css).toString 'base64'}"

compileCss 'one'
  .then -> compileCss 'two'
  .then -> compileCss('three').then (three) ->
    compileHtml three: dataUri three
