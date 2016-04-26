package tink.web.macros;

import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.Expr;

using haxe.macro.Tools;
using tink.MacroApi;

private typedef Handler = {
  name:String,
  func:Function,
}

class Routing {  
  
  var type:Type;
  var ct:ComplexType;
  var fields:Array<Field>;
  var cases:Array<{ pattern: Array<Expr>, guard:Expr, response: Expr, }>;
  var max:Int = 0;
  
  function new(type) {
    this.type = type;
    this.ct = type.toComplex();
    this.fields = [];
    this.cases = [];
    
    build();
  }
  
  static function isUpper(s:String) 
    return s.toUpperCase() == s;
  
  static var verbs = 
    switch Context.getType('tink.http.Method') {
      case TAbstract(_.get() => a, _):
        [for (f in a.impl.get().statics.get()) if (isUpper(f.name)) f.name];
      default:
        throw 'assert';
    }
    
  static var metas = {
    var ret = [for (v in verbs) ':'+v.toLowerCase() => macro $i{v}];
    ret[':all'] = macro _;
    ret;
  }  
  
  static function isSpecial(name:String) 
    return switch name {
      case 'request', 'body', 'query': true;
      default: false;
    }  

  function makeHandler(f:ClassField, ?wrap:Expr->Expr):Handler {
    var fName = f.name;
    var name = 'call_$fName';
    
    if (wrap == null)
      wrap = function (e) return macro @:pos(e.pos) ($e : tink.web.Response);
    
    function ret(e:Expr)
      return macro @:pos(e.pos) return ${wrap(e)};
      
    var func:Function = 
      switch f.type.reduce() {
        case TFun(args, r):
          
          var callArgs = new Array<Expr>(),
              funcArgs = new Array<FunctionArg>();
              
          for (a in args)
            if (isSpecial(a.name))
              throw 'ni';
            else {
              callArgs.push(macro $i{a.name});
              var ct = a.t.toComplex();
              
              switch (macro @:pos(f.pos) ((null : tink.web.Stringly) : $ct)).typeof() {
                case Failure(e):
                  f.pos.error('Routing cannot provide value for function argument ${a.name} of type ${a.t.toString()}');
                default:
              }
              
              funcArgs.push({
                type: macro : tink.web.Stringly,
                name: a.name,
                opt: a.opt,
              });
            }
          {
            args: funcArgs,
            ret: null,
            expr: ret(macro @:pos(f.pos) __target.$fName($a{callArgs})),
          }
        case v:
          
          {
            args: [],
            ret: null,
            expr: ret(macro @:pos(f.pos) __target.$fName),
          };
          
      }  
          
    fields.push({
      name: name,
      pos: f.pos,
      kind: FFun(func),
    });
    
    return { func: func, name: name, }
  }  
  
  function hasRoute(f:ClassField) {
    for (m in metas.keys())
      if (f.meta.has(m)) return true;
    return false;
  }  
  
  function build() {
    
    function add(verb:Expr, pattern:Array<Expr>, response:Expr, guard:Expr) {
      
      pattern = [verb].concat(pattern);
      
      if (pattern.length > max)
        max = pattern.length;
      
      cases.push({
        pattern: pattern,
        guard: guard,
        response: response,
      });
    }    
    
    
    for (c in cases)
      while (c.pattern.length < max)
        c.pattern.push(c.pattern[c.pattern.length - 1]);
    
    var switchTarget = [macro request.header.method];
    
    for (i in 0...max - 1)
      switchTarget.push(macro __parts[$v{i}]);
    
    var body = ESwitch(
      switchTarget.toArray(),
      [for (c in cases) {
        values: [macro @:pos(c.response.pos) $a{c.pattern}],
        guard: c.guard,
        expr: c.response,
      }],
    macro fallback(this)
    ).at();  
    
    var f = (macro class {
      public function route():Response {
        return $body;
      }
    }).fields;
    
    for (f in f)
      this.fields.push(f);
  }
  
  static function getType(name) 
    return 
      switch Context.getLocalType() {
        case TInst(_.toString() == name => true, [v]):
          v;
        default:
          throw 'assert';
      }  
      
  
  static function buildContext(type:Type):Type {
    //TODO: add cache
    var counter = counter++;
    var name = 'RoutingContext$counter',
        ct = type.toComplex();
        
    var decl = macro class $name extends tink.web.Router.RoutingContext<$ct> {
      
    }
    
    decl.fields = decl.fields.concat(new Routing(type).fields);
    
    return declare(decl);
  }
  
  static function declare(t:TypeDefinition):Type {
    var name = 'tink.web.routes.${t.name}';
    Context.defineModule(name, [t]);
    return Context.getType(name);
  }
  
  static var counter = 0;
  
  static function buildRouter():Type {

    var type = getType('tink.web.Router'),
        ct = type.toComplex(),
        router = 'Router${counter++}';
        
    var ctx = buildContext(type).toString().asTypePath();
    
    return declare(macro class $router {
      
      public function new() { }
      
      public function route(target:$ct, request:Request, ?fallback) 
        return 
          if (fallback == null) 
            route(target, request, function (_):Response return new tink.core.Error(NotFound, 'Not Found'));
          else 
            new $ctx(target, request, fallback).route();
    });
    
  }
  
}