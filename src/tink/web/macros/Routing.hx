package tink.web.macros;

import haxe.ds.Option;
import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.Expr;
import tink.web.macros.Route;
import tink.macro.BuildCache;
import tink.http.Method;
import tink.web.routing.Response;

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
    ];
    
    for (i in 0...depth * 2 + named.length * 2 + 1)
      pattern.push(IGNORE);
      
    for (i in 0...v.path.parts.length)
      pattern[i + 1 + depth] = macro true;
      
    if (v.path.rest == RNotAllowed)
      pattern[depth + 1 + v.path.parts.length] = macro false;
      
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
      pattern[i + 1] = part(v.path.parts[i]);
      
    for (name in v.path.query.keys()) {
      
      var index = nameIndex[name];
      
      pattern[index + 2 + depth] = macro true;
      pattern[index + 2 + depth + named.length] = part(v.path.query[name]);
    }
    
    var callArgs = [for (a in funcArgs) 
      if (a == funcArgs[0] || captured[a.name]) macro $i{a.name}
      else if (a.name == '__depth__') macro $v{v.path.parts.length}
      else macro null //wtf?
    ];
    
    return { 
      values: [pattern.toArray(v.path.pos)],
      expr: macro @:pos(v.path.pos) this.$field($a{callArgs}),
    } 
  }  

  function switchTarget() {
    var ret = [macro ctx.header.method];
    
    for (i in 0...depth) 
      ret.push(macro ctx.part($v { i } ));
      
    for (i in 0...depth+1) 
      ret.push(macro l > $v{i});
      
    for (name in named) 
      ret.push(macro ctx.hasParam($v{name}));
    
    for (name in named) 
      ret.push(macro ctx.param($v{name}));
      
    return ret.toArray();
  }
  
  function restrict(meta:Array<MetadataEntry>, e:Expr) {
    switch [meta, session] {
      case [[], None]: 
      case [v, None]:
        v[0].pos.error('restriction cannot be applied because no session handling is provided');
      case [_, Some(_)]: 
        
        for (m in meta)
          switch m.params {
            case []:
              m.pos.error('@:restrict must have one parameter');
            case [v]:
              
            case v:
              v[1].reject('@:restrict must have one parameter');
          }     
    }
    return e;
  }
  
  function generate(name:String, target:ComplexType, pos:Position) {
    
    secondPass();

    var theSwitch = ESwitch(
      switchTarget(), 
      cases, 
      macro @:pos(pos) new tink.core.Error(NotFound, 'Not Found')
    ).at(pos);
    
    var ret = 
      switch session {
        case Some(ct):
          
          
          
          macro class $name {
            
            var target:$target;
            var getSession:tink.http.Request.IncomingRequestHeader->$ct;
            
            public function new(target, getSession) {
              this.target = target;
              this.getSession = getSession;
            }
            
            public function route(ctx:tink.web.routing.Context, ?user):tink.core.Promise<tink.http.Response.OutgoingResponse> {
              if (user == null)
                user = tink.core.Promise.lift(
                  tink.core.Future.async(function (cb)
                    this.getSession(ctx.header).getUser().handle(cb)
                  )
                );
              var l = ctx.pathLength;
              return $theSwitch;
            }
          };          
        default:
          macro class $name {
            
            var target:$target;
            
            public function new(target) {
              this.target = target;
            }
            
            public function route(ctx:tink.web.routing.Context):tink.core.Promise<tink.http.Response.OutgoingResponse> {
              var l = ctx.pathLength;
              return $theSwitch;
            }
          };
      }
    
    for (f in fields)
      ret.fields.push(f);
      
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
     
    var result = macro @:pos(pos) this.target.$field;
    
    if (route.field.type.reduce().match(TFun(_, _)))
      result = macro @:pos(pos) $result($a{callArgs});
    
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
                new tink.web.routing.Router<$target>(__target__).route(ctx.sub(__depth__))
            );
          
        case KCall(c):
          switch c.response {
            case RData(t):
              var ct = t.toComplex();
              var formats = [];
              
              switch route.field.meta.extract(':html') {
                case []: 
                case [{ pos: pos, params: [v] }]:
                  formats.push(
                    macro @:pos(pos) if (ctx.accepts('text/html')) 
                      return tink.core.Promise.lift($v(__data__)).next(
                        function (d) return tink.web.routing.Response.textual('text/html', d)
                      )
                  );
                case [v]: 
                  v.pos.error('@:html must have one argument exactly');
                case v:
                  v[1].pos.error('Cannot have multiple @:html directives');
              }
              
              for (fmt in route.produces)
                formats.push(
                  macro @:pos(pos) if (ctx.accepts($v{fmt})) return tink.web.routing.Response.textual(
                    $v{fmt}, ${MimeType.writers.get([fmt], t, pos)}(__data__)
                  )
                );
                
              macro @:pos(pos) tink.core.Promise.lift($result).next(
                function (__data__:$ct):tink.core.Promise<tink.web.routing.Response> {
                  $b{formats};
                  return new tink.core.Error(UnsupportedMediaType, 'Unsupported Media Type');
                }
              );
              
            case ROpaque(_.toComplex() => t):
              macro @:pos(pos) tink.core.Promise.lift($result).next(function (v:$t):tink.web.routing.Response return v);
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
              
              if (separate != null)
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
                  var cases:Array<Case> = [];
                  
                  var structured = [];
                  
                  for (type in route.consumes) 
                    switch type {
                      case 'application/x-www-form-urlencoded' | 'multipart/form-data': 
                        structured.push(macro @:pos(pos) $v{type});
                      default: 
                        cases.push({ 
                          values: [macro $v{type}],
                          expr: macro @:pos(pos) tink.core.Promise.lift(ctx.rawBody.all()).next(
                            function (b) return ${MimeType.readers.get([type], sum.toType(pos).sure(), pos)}(b.toString())
                          )
                        });
                    }
                  
                  switch structured {
                    case []:
                    case v:
                      cases.unshift({ 
                        values: structured, 
                        expr: macro @:pos(pos) ctx.parse().next(function (pairs)
                          return new tink.querystring.Parser<tink.web.forms.FormField->$sum>().tryParse(pairs)
                        ),
                      });
                  }
                  
                  var contentType = macro @:pos(pos) switch ctx.header.contentType() {
                    case Success(v): v.fullType;
                    default: 'application/json';
                  }
                  
                  cases.push({ 
                    values: [macro invalid],
                    expr: macro new tink.core.Error(NotAcceptable, 'Cannot process Content-Type '+invalid),
                  });
                  
                  macro @:pos(pos) (
                    ${ESwitch(contentType, cases, null).at(pos)} 
                      : 
                    tink.core.Promise<$sum>
                  );
                case PHeader:
                  macro @:pos(pos) tink.core.Promise.lift(
                    new tink.querystring.Parser<tink.http.Header.HeaderValue->$sum>().tryParse(ctx.headers())
                  );
                case PQuery:
                  macro tink.core.Promise.lift(
                    new tink.querystring.Parser<$sum>().tryParse(ctx.header.uri.query)
                  );
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
          for (v in s.variants)  
            cases.push(makeCase(route.field.name, args, v, None));
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
        (macro @:pos(ctx.pos) {
          var x:$s = null;
          function test<U>(s:tink.web.Session<U>) {
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