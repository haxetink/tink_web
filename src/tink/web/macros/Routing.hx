package tink.web.macros;

import haxe.ds.Option;
import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.Expr;
import tink.web.macros.Route;
import tink.macro.BuildCache;
import tink.http.Method;

using tink.MacroApi;
using tink.CoreApi;
using Lambda;

class Routing { 
  
  var routes:Array<Route>;
  var session:Option<ComplexType>;
  
  var cases:Array<Case> = [];
  var fields:Array<Field> = [];
  
  var depth:Int = 0;
  var named:Array<String> = [];
  var nameIndex:Map<String, Int> = new Map();

  function new(routes, session) {
    
    this.routes = routes;
    this.session = session;
        
    firstPass();
  }
  
  function firstPass() {
    //during the first pass we skim all routes to map out their depths and named parameters
    for (route in routes) {
      
      function skim(variants:Iterable<Variant>) 
        for (v in variants) {
          
          switch v.path.parts.length {
            case sup if (sup > depth):
              depth = sup;
            default:
          }
          
          for (name in v.path.query.keys())
            if (!nameIndex.exists(name))
              nameIndex[name] = named.push(name) - 1;
        }
      
      switch route.kind {
        case KSub(s):
          skim(s.variants);
        case KCall(c):
          skim(c.variants);
      }
      
    } 
    
  }
  
  function makeCase(field:String, funcArgs:Array<FunctionArg>, v:Variant, method:Option<Method>):Case {
    if (v.path.deviation.missing.length > 0)
      v.path.pos.error('Route does not capture all required variables. See warnings.');
      
    var pattern = [
      switch method {
        case Some(m): macro $i{m};
        case None: IGNORE;
      },
      switch v.path.rest {
        case RNotAllowed: macro $v{v.path.parts.length}; 
        default: IGNORE;
      }
    ];
    
    for (i in 0...depth + named.length * 2)
      pattern.push(IGNORE);
      
    var captured = new Map();
      
    function part(p)
      return switch p {
        case PConst(v): 
          macro $v{v.toString()};                
        case PCapture(name): 
          captured[name] = true;
          macro $i{name};
      }
      
    for (i in 0...v.path.parts.length)
      pattern[i + 2] = part(v.path.parts[i]);
      
    for (name in v.path.query.keys()) {
      
      var index = nameIndex[name];
      
      pattern[index + 2 + depth] = macro true;
      pattern[index + 2 + depth + named.length] = part(v.path.query[name]);
    }
    
    var callArgs = [for (a in funcArgs) 
      if (a == funcArgs[0] || captured[a.name]) macro $i{a.name}
      else macro null //wtf?
    ];
    
    return { 
      values: [pattern.toArray(v.path.pos)],
      expr: macro this.$field($a{callArgs}),
    } 
  }  

  function switchTarget() {
    var ret = [macro ctx.header.method, macro ctx.pathLength];
    
    for (i in 0...depth)
      ret.push(macro ctx.part($v{i}));
      
    for (name in named) 
      ret.push(macro ctx.hasParam($v{name}));
    
    for (name in named) 
      ret.push(macro ctx.param($v{name}));
      
    return ret.toArray();
  }
  
  function generate(name:String, target:ComplexType, pos:Position) {
    
    secondPass();

    var theSwitch = ESwitch(
      switchTarget(), 
      cases, 
      macro @:pos(pos) new tink.core.Error(NotFound, 'Not Found')
    ).at(pos);
    
    var ret = macro class $name {
      
      var target:$target;
      
      public function new(target) {
        this.target = target;
      }
      
      public function route(ctx:tink.web.routing.Context):tink.core.Promise<tink.http.Response.OutgoingResponse> {
        return $theSwitch;
      }
    };
    
    for (f in fields)
      ret.fields.push(f);
    
    //trace(TAnonymous(ret.fields).toString());
      
    return ret;    
  }
  
  function routeMethod(route:Route) {
    var separate = new Map<ParamLocation, Array<Field>>(),
        compound = new Map<ParamLocation, Array<Named<Type>>>(),
        pos = route.field.pos,
        callArgs = [],
        funcArgs:Array<FunctionArg> = [{
          name: 'ctx',
          type: macro : tink.web.routing.Context,
        }];
        
    var field = route.field.name;
            
    for (arg in route.signature) {
      
      switch arg.kind {
        case ACapture:
                      
          funcArgs.push({
            name: arg.name,
            type: macro : tink.Stringly,
            opt: arg.optional,
          });
          
        case AParam(t, loc, PCompound):
          
          if (!compound.exists(loc))
            compound[loc] = [];
            
          compound[loc].push(new Named(arg.name, t));
          
        case AParam(t, loc, PSeparate):
          
          if (!separate.exists(loc))
            separate[loc] = [];
            
          separate[loc].push({
            name: arg.name,
            pos: route.field.pos,
            kind: FVar(t.toComplex()),
          });
          
        default:
          
          throw 'not implemented: '+arg.kind;
      }
      
      callArgs.push(arg.name.resolve());        
    }
     
    var result = macro @:pos(pos) this.target.$field($a{callArgs});
    
    result = 
      switch route.kind {
        case KSub(s):
          funcArgs.push({
            name: '__depth__',
            type: macro : Int,
          });
          
          var target = s.target.toComplex();
          
          macro @:pos(pos) tink.core.Promise.lift($result)
            .next(function (__target__:$target) 
              return 
                new tink.web.routing.Router<$target>(result).route(ctx.sub(__depth__))
            );
          
        case KCall(c):
          switch c.response {
            case RData(_.toComplex() => t):
              
              var render = 
                switch route.field.meta.extract(':html') {
                  case []: 
                    macro { };
                  case [{ params: [v] }]:
                    macro if (ctx.accepts('text/html')) 
                      return tink.core.Promise.lift($v(__data__)).next(
                        function (d):tink.web.Response return d
                      ); 
                  case [v]: 
                    v.pos.error('@:html must have one argument exactly');
                  case v:
                    v[1].pos.error('Cannot have multiple @:html directives');
                }
                
              macro @:pos(pos) tink.core.Promise.lift($result).next(function (__data__:$t) {
                $render;
                var ret:tink.core.Promise<tink.web.Response> = new tink.core.Error(UnsupportedMediaType, 'Unsupported Media Type');
                return ret;
              });
              
              
            case ROpaque(_.toComplex() => t):
              macro @:pos(pos) tink.core.Promise.lift($result).next(function (v:$t):tink.web.Response return v);
          }
      }
      
    for (loc in [PBody, PQuery, PHeader]) {
      
      var locName = loc.getName().substr(1).toLowerCase();
      
      result = 
        switch [loc, separate[loc], compound[loc]] {
          case [_, null, null]:
            result;//there's nothing to be done here
          case [PBody, null, [raw]] if (raw.value.isSubTypeOf(Context.getType('tink.io.Source'))):
            
            var name = raw.name;
            macro @:pos(pos) {
              var $name = ctx.rawBody;
              $result;
            }
            
          case [PBody, null, [buffered]] if (buffered.value.isSubTypeOf(Context.getType('haxe.io.Bytes')).isSuccess()):
            
            var name = buffered.name;
            
            macro @:pos(pos) 
              tink.core.Promise.lift(ctx.rawBody.all())
                .next(function ($name:haxe.io.Bytes) 
                  return $result
                );
              
          case [PBody, null, [textual]] if (textual.value.isSubTypeOf(Context.getType('String')).isSuccess()):
            
            var name = textual.name;
            
            macro @:pos(pos) 
              tink.core.Promise.lift(ctx.rawBody.all())
                .next(function ($name:haxe.io.Bytes) {
                  var $name = $i{name}.toString();
                  return $result;
                });
            
          case [_, separate, compound]:
            
            if (compound == null)
              compound = [];
              
            if (separate != null)
              compound.push(new Named('', ComplexType.TAnonymous(separate).toType().sure()));
              
            var sum = switch compound {
              case [v]: 
                v.value.toComplex();
              case v:
                
                var fields = [];
                
                for (t in v)
                  switch t.value.reduce().toComplex() {
                    case TAnonymous(f):
                      for (f in f)
                        fields.push(f);
                    default:
                      route.field.pos.error('If multiple types are defined for $locName then all must be anonymous objects');
                  }
                  
                ComplexType.TAnonymous(fields);
            }
            
            var locVar = '__${locName}__';
            
            function dissect() {
              var target = locVar.resolve();
              var parts:Array<Var> = [];
              
              for (s in separate)
                parts.push({ name: s.name, type: null, expr: target.field(s.name) });
              
              for (c in compound) 
                if (c.name != '')
                  switch c.value.reduce().toComplex() {//TODO: deduplicate - we're getting this above already
                    case TAnonymous(fields):
                      parts.push({ 
                        name: c.name, 
                        type: TAnonymous(fields),
                        expr: EObjectDecl([for (f in fields) {
                          field: f.name,
                          expr: target.field(f.name)
                        }]).at(),
                      });
                    default:
                      throw 'assert';
                  };
                
              return EVars(parts).at();
            }
            
            var promise = 
              switch loc {
                case PBody:
                  throw 'not implemented';
                case PHeader:
                  throw 'not implemented';
                case PQuery:
                  macro tink.core.Promise.lift(new tink.querystring.Parser<$sum>().tryParse(ctx.header.uri.query));
              }
            
            macro return $promise.next(function ($locVar) {
              ${dissect()};
              return $result;
            });
        }
        
      if (loc == PBody) {
        //TODO: apply access control
      }
    }    
    
    var f:Function = {
      args: funcArgs,
      expr: macro @:pos(result.pos) return $result,
      ret: null,
    }
    
    fields.push({
      pos: pos,
      name: route.field.name,
      kind: FFun(f),
    });
    
    return funcArgs;
  }
  
  function secondPass() 
    for (route in routes) {
      var args = routeMethod(route);
            
      switch route.kind {
        case KCall(c):
          for (v in c.variants)
            cases.push(makeCase(route.field.name, args, v, v.method));
        case KSub(s):
      }
    }
  
  static var IGNORE = macro _;
  
  static function build(ctx:BuildContextN) {
    
    var session = None;
    
    var target = switch ctx.types {
      case []:
        switch Context.getCallArguments() {
          case null | []:
            ctx.pos.error('You must either specify a target type as type parameter or a target object as constructor argument');
          case [v]:
            v.typeof().sure();
          case _:
            ctx.pos.error('too many arguments - only one expected');
        }
      case [t]: t;
      case [s, t]:
        var s = s.toComplex();
        (macro {
          var x:$s = null;
          function test<U>(s:Session<U>) {
            return s;
          }
          test(x);
        }).typeof().sure();
        session = Some(s);
        t;
      default:
        ctx.pos.error('Invalid usage');
    }
    
    return new Routing(
      RouteSyntax.read(
        target,
        ['multipart/form-data', 'application/x-www-form-urlencoded', 'application/json'], 
        ['application/json']
      ),
      session
    ).generate(ctx.name, target.toComplex(), ctx.pos);
  }
  
  static function apply() {
    return BuildCache.getTypeN('tink.web.routing.Router', build);
  }
  
}