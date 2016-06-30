package tink.web.macros;

import haxe.macro.Expr;
import haxe.macro.Type;
import tink.web.macros.Rule;
import tink.macro.BuildCache;

using haxe.macro.Tools;
using tink.MacroApi;

class ProxyBuilder {

  static function build() {
    return BuildCache.getType('tink.web.Proxy', makeProxy);
    //return proxyFor(Routing.getType('tink.web.Proxy'));
  }
  
  static function makeProxy(ctx:BuildContext) {
    var ct = ctx.type.toComplex(),
        name = ctx.name;
    
    var ret = macro class $name extends tink.web.Proxy.ProxyBase<$ct> {
      
    }
    
    for (r in Rules.read(ctx.type)) {
      switch r.kind {
        case Sub(_): 
          //r.field.pos.error('no support for subrouting just yet');
        case Calls(calls):
          
          var call = calls[0];
          
          switch call.method {
            case Some(method):
              
              if (call.rest != Exact)
                throw 'not implemented';
              
              var args = new Array<FunctionArg>();
              
              function add(name, t:Type)
                args.push({
                  name: name,
                  type: t.toComplex(),
                });
                
              var exprs = [macro var __headers = [], __body = null, __query = ''];
              
              for (arg in r.signature.args)
                switch arg {
                  case AQuery(t): 
                    add('query', t);
                    exprs.push(macro __query = '?'+tink.web.QueryComposer.query(query));
                    //exprs.push(macro trace(query));
                  case ABody(t): 
                    add('body', t);
                    //trace(t.toString());
                    //exprs.push(macro var body = haxe.io.Bytes.ofString(tink.Json.stringify(body)));
                    //exprs.push(macro __headers.push(new tink.http.Header.HeaderField('Content-Type', 'application/json')));
                    //exprs.push(macro __headers.push(new tink.http.Header.HeaderField('Content-Length', 'application/json')));
                  case APath:
                  case APart(name, t): 
                    add(name, t);
                    
                }
                
              var path = macro '';
              
              function add(e)
                path = macro $path + '/' + $e;
              
              for (arg in call.path)
                add(switch arg {
                  case Arg(name, _):
                    macro (($i{name}:tink.web.Stringly):String);
                  case Const(v):
                    macro $v{v};
                });
                
              exprs.push(macro this.makeRequest($i{method}, $path + __query, __headers, __body));
              
              ret.fields.push({
                pos: r.field.pos,
                name: r.field.name,
                access: [APublic],
                kind: FFun({
                  args: args,
                  ret: null,
                  expr: (macro $b{exprs}).log(),
                })
              });
              
            default:
          }
      }
    }
    
    return ret;
  }
  
}