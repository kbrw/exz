var Server = require('node_erlastic').server,
    Bert = require('node_erlastic/bert'),
    Domain = require('domain'),
    htmlParser = require("htmlparser2"),
    cssSelector = require("css-select"),
    fs = require("fs"),
    deepcopy = require("deepcopy"),
    path = require("path")
Bert.all_binaries_as_string = true

function domToBert(dom,tagIndex){
  if (dom.type==='tag'){
    var zsel = (typeof dom.zselidx === 'undefined') ? null : Bert.tuple(dom.zselidx,dom.zmatchidx)
    return Bert.tuple(dom.name.toLowerCase(),zsel,dom.attribs,dom.children.filter(
          function(child){return child.type === 'text' || child.type === 'tag'}
        ).map(function(child){
          var bert = domToBert(child,tagIndex)
          return bert
        }))
  }else if(dom.type==='text'){
    return dom.data.toString()
  }
  return null
}

var current_ref = 0
Server(function(term,from,state,done){
  try {
    var req=term[0].toString()
    if(req === "parse_file" ) {
      var html_file = term[1].toString(), sel = term[2].toString(), zsels = term[3]
      var parser = new htmlParser.Parser(
        new htmlParser.DomHandler(function (err, dom) {
          if (err){ done("reply",Bert.tuple(Bert.atom("error"), "fail_to_parse")) }
          var dom = cssSelector.selectOne(sel,dom)
          zsels.forEach(function (zsel, zselidx){
            cssSelector(zsel,dom).forEach(function (subdom,i){
              subdom.zselidx = zselidx
              subdom.zmatchidx = i
            })
          })
          //  if (!dom) error("selector "+jsxZ.rootSelector+" does not match any node in "+ jsxZ.htmlPath,jsxZ.selNode)
          done("reply",domToBert(dom,1))
        }))
      parser.write(fs.readFileSync(html_file, 'utf8'))
      parser.done()
    }
  } catch (err) {
    done("reply","error")
  }
},function(init){
  return {}
})
