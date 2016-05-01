package tink.web.macros;

import haxe.macro.Expr;
import haxe.macro.Type;
import tink.core.Pair;
import tink.http.Method;

using tink.MacroApi;
using StringTools;

typedef Rule = {
  var field(default, null):ClassField;
  var kind(default, null):RuleKind;
  var signature(default, null):RuleSignature;
}

typedef RuleSignature = {
  var args(default, null):Array<RuleArg>;
  var ret(default, null):Type;
}

enum RuleArg {
  APart(name:String, t:Type);
  ABody(t:Type);
  AQuery(t:Type);
  APath;
}

enum RuleKind {
  Calls(calls:Array<Call>);
  Sub(subroutes:Array<SubRoute>);
}

typedef Call = {
  var method(default, null):Option<Method>;
  var path(default, null):RulePath;
  var rest(default, null):PathRest;
}

enum PathRest {
  Exact;
  Ignore;
  Capture(name:String);
}

typedef RulePath = Array<PathPart>;

enum PathPart {
  Const(s:String);
  Arg(name:String);
}

typedef SubRoute = {
  path:RulePath,
}

class Rules {
  
  static var metas = {
    var ret = [for (m in [GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE]) ':$m'.toLowerCase() => Some(m)];
    
    ret[':all'] = None;
    
    ret;
  }
  
  static function hasRoute(f:ClassField) {
    for (m in metas.keys())
      if (f.meta.has(m)) return true;
    return false;
  }  
  
  static function makeSignature(f:ClassField):RuleSignature {
    return
      switch f.type.reduce() {
        case TFun(args, r):
          
          {
            args:
              [for (a in args)
                switch a.name {
                  case 'path':
                    APath;
                  case 'body':
                    ABody(a.t);
                  case 'query':
                    AQuery(a.t);
                  case 'context':
                    f.pos.error('Argument name "context" is reserved but currently invalid');
                  case v: 
                    APart(v, a.t);
                }
              ],
            ret: r,
          }
            
        case v: { args: [], ret: v };
      }
  }
  
  static function getPath(f:ClassField, m:MetadataEntry):Pair<RulePath, PathRest> {
    return
      switch m.params {
        case null | []: 
          new Pair([Const(f.name)], Exact);
        case [v]: 
          
          var uri:Url = v.getName().sure(),
              parts = uri.path.parts();
          
          var rest = switch parts[parts.length - 1] {
            case '*': Ignore;
            case null: Exact;
            case named if (named.startsWith('*')): Capture(named.substr(1));
            default: Exact;
          }
          
          if (rest != Exact)
            parts.pop();
            
          new Pair([for (p in parts) 
            if (p.startsWith("$")) Arg(p.substr(1))
            else Const(p)
          ], rest);
        case v: 
          v[1].reject('Not Implemented');
      }
    
  }
  
  static public function read(t:Type) {
    
    var ret = new Array<Rule>();
    
    for (f in t.getFields().sure()) {
      var meta = f.meta.get();
      
      switch [hasRoute(f), [for (m in meta) if (m.name == ':sub') m]] {
        
        case [true, []]:
          
          function makeCalls(f:ClassField) {
            
            var ret = new Array<Call>();
            
            for (m in meta)
              switch metas[m.name] {
                case null:
                case method:
                  
                  var sig = getPath(f, m);
                  
                  ret.push({
                    method: method,
                    path: sig.a,
                    rest: sig.b,
                  });
              }
              
            return ret;
          }
          
          ret.push({
            field: f,
            kind: Calls(makeCalls(f)),
            signature: makeSignature(f),
          });
          
        case [true, v]:
          
          f.pos.error('cannot have both routing and subrouting on the same field');
          
        case [false, []]:
          
        case [false, sub]:
          
          ret.push({
            field: f,
            signature: makeSignature(f),
            kind: Sub([for (s in sub) switch getPath(f, s) {
              case { a: path, b: Exact }: { path: path };
              default: s.pos.error('subrouting paths must be exact');
            }]),
          });
          
      }
    }
    
    return ret;
  }
}