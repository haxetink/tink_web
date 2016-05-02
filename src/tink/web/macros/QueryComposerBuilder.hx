package tink.web.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

import tink.typecrawler.Crawler;
import tink.typecrawler.FieldInfo;
import tink.typecrawler.Generator;

using haxe.macro.Tools;
using tink.MacroApi;

class QueryComposerBuilder {  
  
  static function buildNew(pos:Position, type:Type, usings, name:String) {
    
    var ret = macro class $name {
      public function new() {}
      //public function tryParse()
        //return tink.core.Error.catchExceptions(this.parse);
    }
    
    function add(t:TypeDefinition)
      for (f in t.fields)
        ret.fields.push(f);
        
    var crawl = Crawler.crawl(type, pos, QueryComposerBuilder);
    
    ret.fields = ret.fields.concat(crawl.fields);
    
    add(macro class {
      public function compose(value):tink.url.Query {
        var prefix = '',
            builder = new tink.url.Query.QueryStringBuilder();
        ${crawl.expr};
        return builder.toString();
      }
    });    
        
    return ret;
  }
  
  static public function args():Array<String> 
    return ['builder', 'prefix', 'value'];
    
  static public function nullable(e:Expr):Expr 
    return 
      macro if (value != null) $e;
    
  static public function string():Expr 
    return 
      macro builder.add(prefix, value);
    
  static public function float():Expr
    return 
      macro {
        var value = Std.string(value);
        ${string()};
      }
  
  static public function int():Expr 
    return
      macro {
        var value = Std.string(value);
        ${string()};
      }
      
  static public function dyn(e:Expr, ct:ComplexType):Expr {
    return throw "not implemented";
  }
  static public function dynAccess(e:Expr):Expr {
    return throw "not implemented";
  }
  static public function bool():Expr {
    return throw "not implemented";
  }
  static public function date():Expr {
    return throw "not implemented";
  }
  static public function bytes():Expr {
    return throw "not implemented";
  }  
  
  
  static public function anon(fields:Array<FieldInfo>, ct:ComplexType):Function {
    var exprs = [];
    for (f in fields) {
      var name = f.name;
      exprs.push(macro @:pos(f.pos) {
        var value = value.$name,
            prefix = switch prefix {
              case '': $v{f.name};
              case v: v + $v{ '.' + f.name};
            }
        ${f.expr};
      });
    }
    
    return 
      (macro function (builder:tink.url.Query.QueryStringBuilder, prefix:String, value:$ct) $b{exprs}).getFunction().sure();
  }
  
  static public function array(e:Expr):Expr 
    return macro 
      for (i in 0...value.length) {
        var prefix = prefix + '[' + i + ']',
            value = value[i];
        $e;
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
  
  static public function build(?type:Type, ?pos:Position) 
    return Cache.getType('tink.web.QueryComposer', type, pos, buildNew);
}