package tink.web.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using tink.MacroApi;

abstract MimeType(String) from String to String {
  
  static function typedString(e:Expr) 
    return switch Context.typeExpr(e) {
      case { expr: TConst(TString(s)) }:
        s;
      case t: 
        e.reject('Expected String but found $t');
    }  
  
  static public function fromMeta(meta:MetaAccess, kind:String, old:Array<MimeType>) 
    return switch [for (m in meta.extract(':$kind')) for (e in m.params) e] {
      case []: old;
      case v:
        function isUnop(e:Expr)
          return e.expr.match(EUnop(_, _, _));
        
        switch v.filter(isUnop) {
          case []:
            
            [for (e in v) typedString(e)];
            
          case mixed if (mixed.length < v.length):
            
            mixed[0].reject('you must either modify or replace mime types');
            
          case all:
            
            var ret = old.copy();
            
            for (e in v)
              switch e {
                case (macro --$e) | (macro $e--):
                  ret.remove(typedString(e));
                case (macro ++$e) | (macro $e++):
                  var s = typedString(e);
                  while (ret.remove(s)) { }
                  ret.push(s); 
                default: 
                  e.reject();
              }
              
            ret;
        }
        
    }
  
  static public var readers(default, null) = new Registry('reader', [
    'application/json' => function (type:Type, pos:Position) {
      var ct = type.toComplex({ direct: true });
      return macro @:pos(pos) new tink.json.Parser<$ct>().tryParse;
    },
  ]);
  static public var writers(default, null) = new Registry('writer', [
    'application/json' => function (type:Type, pos:Position) {
      var ct = type.toComplex( { direct: true } );
      return macro @:pos(pos) new tink.json.Writer<$ct>().write;
    },
    'application/x-www-form-urlencoded' => function (type:Type, pos:Position) {
      var ct = type.toComplex( { direct: true } );
      return macro @:pos(pos) new tink.querystring.Builder<$ct>().stringify;
    },
  ]);
  
}

private class Registry {
  var map:Map<MimeType, Type->Position->Expr>;
  var kind:String;
  
  public function new(kind, map) {
    this.kind = kind;
    this.map = map;
  }
  
  public function register(type:MimeType, reader:Type->Expr) 
    if (map.exists(type))
      throw 'Duplicate registration for type $type';
        
  public function get(options:Array<MimeType>, type, pos:Position) {
    
    for (a in options)
      switch map[a] {
        case null:
        case gen: return { type: a, generator: gen(type, pos) };
      }
      
    options = options.copy();
    var last = options.pop();
    return pos.error('No $kind available for '+ switch options {
      case []: 'mime type $last';
      default: 'any of the mime types ' + options.join(', ') + ' or $last';
    }); 
  }
}