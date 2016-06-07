package tink.web.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import tink.macro.BuildCache;

import tink.typecrawler.Crawler;
import tink.typecrawler.FieldInfo;
import tink.typecrawler.Generator;

using haxe.macro.Tools;
using tink.MacroApi;

class QueryParserBuilder { 
  
  static function buildNew(ctx:BuildContext, body:Bool) {
    var name = ctx.name;
    var vType = if (body) macro : tink.web.helpers.FormField else macro : tink.web.Stringly;
    var ret = macro class $name extends tink.web.helpers.QueryParserBase<$vType> {
      public function tryParse()
        return tink.core.Error.catchExceptions(this.parse);
    }
    
    function add(t:TypeDefinition)
      for (f in t.fields)
        ret.fields.push(f);
        
    var crawl = Crawler.crawl(ctx.type, ctx.pos, QueryParserBuilder);
    
    ret.fields = ret.fields.concat(crawl.fields);
    
    add(macro class {
      public function parse() {
        var prefix = '';
        return ${crawl.expr};
      }
    });    
        
    return ret;
  }
  
  static public function build(type:Type, pos:Position, body:Bool) 
    return BuildCache.getType('tink.web.QueryParser', type, pos, buildNew.bind(_, body));
  
  static public function args():Array<String> 
    return ['prefix'];
    
  static public function nullable(e:Expr):Expr 
    return 
      macro 
        if (exists[prefix]) $e;
        else null;
    
  static public function string():Expr 
    return 
      macro 
        if (exists[prefix]) params[prefix];
        else missing(prefix);
    
  static public function float():Expr
    return macro Std.parseFloat(${string()});
  
  static public function int():Expr 
    return macro Std.parseInt(${string()});
    
  static public function dyn(e:Expr, ct:ComplexType):Expr {
    return throw "not implemented";
  }
  static public function dynAccess(e:Expr):Expr {
    return throw "not implemented";
  }
  static public function bool():Expr {
    return macro (${string()}) == 'true';
  }
  static public function date():Expr {
    return throw "not implemented";
  }
  static public function bytes():Expr {
    return throw "not implemented";
  }
  
  static public function anon(fields:Array<FieldInfo>, ct:ComplexType):Function {
    var ret = [];
    for (f in fields)
      ret.push( { 
        field: f.name, 
        expr: macro {
          var prefix = switch prefix {
            case '': $v{f.name};
            case v: v + $v{ '.' + f.name};
          }
          ${f.expr};
        } 
      });
    return (macro function (prefix:String):$ct {
      return ${EObjectDecl(ret).at()};
    }).getFunction().sure();
  }
  
  static public function array(e:Expr):Expr {
    return macro {
      
      var counter = 0,
          ret = [];
      
      while (true) {
        var prefix = prefix + '[' + counter + ']';
        
        if (exists[prefix]) {
          ret.push($e);
          counter++;
        }
        else break;
      }
      
      ret;
    }
  }
  static public function map(k:Expr, v:Expr):Expr {
    return throw "not implemented";
  }
  static public function enm(constructors:Array<EnumConstructor>, ct:ComplexType, pos:Position, gen:GenType):Expr {
    return throw "not implemented";
  }
  static public function rescue(t:Type, pos:Position, gen:GenType):Option<Expr> {
    return None;
  }
  static public function reject(t:Type):String {
    return throw "not implemented";
  }
  
}