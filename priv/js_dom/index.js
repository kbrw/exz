const Server = require('node_erlastic').server,
      Bert = require('node_erlastic/bert'),
      htmlParser = require("htmlparser2"),
      cssSelector = require("css-select"),
      fs = require("fs")
Bert.all_binaries_as_string = true

function domToBert(dom){
  if (dom.type==='tag'){
    let zsel = (dom.zselidx === undefined) ? null : Bert.tuple(dom.zselidx,dom.zmatchidx)
    return Bert.tuple(dom.name.toLowerCase(),zsel,dom.attribs,dom.children.filter(
          child => (child.type === 'text' || child.type === 'tag')
        ).map( child => domToBert(child) ) )
  }else if(dom.type==='text'){
    return dom.data.toString()
  }
  return null
}

Server((term,from,state,done) => {
  try {
    let [req, ...rest] = Array.from(term)
    if(term[0] == "parse_file" ) {
      let [html_file,sel,zsels] = rest
      let parser = new htmlParser.Parser(
        new htmlParser.DomHandler((err, fulldom) => {
          if (err){ done("reply",Bert.tuple(Bert.atom("error"), "fail_to_parse")) }
          let dom = cssSelector.selectOne(sel,fulldom)
          zsels.forEach( (zsel, zselidx) => {
            cssSelector(zsel,dom).forEach((subdom,i) => {
              subdom.zselidx = zselidx
              subdom.zmatchidx = i
            })
          })
          //  if (!dom) error("selector "+jsxZ.rootSelector+" does not match any node in "+ jsxZ.htmlPath,jsxZ.selNode)
          done("reply",domToBert(dom))
        }))
      parser.write(fs.readFileSync(html_file, 'utf8'))
      parser.done()
    }
  } catch (err) {
    done("reply","error")
  }
},(init) => ({}) )
