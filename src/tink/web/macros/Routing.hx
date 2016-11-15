package tink.web.macros;

import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.Expr;
import tink.web.macros.Rule.Rules;

using haxe.macro.Tools;
using tink.MacroApi;
using Lambda;

private typedef Handler = {
  name:String,
  func:Function,
}

class Routing {  
  static var PACK = 'tink.web.routes';
  
  var target:Type;
  var user:Type;
  var fields:Array<Field>;
  var cases:Array<{ pattern: Array<Expr>, guard:Expr, response: Expr, }>;
  var max:Int = 0;
  
  function new(user, target) {
    
    this.user = user;
    this.target = target;
    
    this.fields = [];
    this.cases = [];
    
    build();
  }
    
  static var verbs = 'GET,HEAD,OPTIONS,PUT,POST,PATCH,DELETE'.split(',');
    
  static var metas = {
    var ret = [for (v in verbs) ':'+v.toLowerCase() => macro $i{v}];
    ret[':all'] = macro _;
    ret;
  }  
  
  static function isSpecial(name:String) 
    return switch name {
      case 'context', 'body', 'query', 'path': true;
      default: false;
    }  
    
  static function mkResponse(e:Expr) 
    return macro @:pos(e.pos) ($e : tink.web.Response);
  
  function getRestriction(meta:MetaAccess)
    return [for (m in meta.extract(':restrict')) for (p in m.params) p];
    
  function makeHandler(f:ClassField, restrictions:Array<Expr>, ?wrap:Expr->Type->Expr):Handler {
    var fName = f.name;
    var name = 'call_$fName';
    
    var restrict = macro (null : tink.web.helpers.AuthResult);
    
    for (r in [restrictions, getRestriction(f.meta)])
      for (r in r) {
        var positioned = macro @:pos(r.pos) ($r : tink.web.helpers.Managed<Bool>);//working around a weird compiler bug with position in the reification below not being applied
        restrict = macro @:pos(r.pos) $restrict && tink.web.helpers.AuthResult.get(this.session, function (user) return $positioned);
      }
    
    
    if (wrap == null)
      wrap = function (e, t) return e;
    
    function ret(e:Expr, t)
      return 
        macro @:pos(e.pos) return 
          try 
            $restrict.respond(${mkResponse(wrap(e, t))}) 
          catch (e:tink.core.Error) { (e:tink.web.Response); } 
          catch (e:Dynamic) { (tink.core.Error.withData(InternalError, 'Internal Server Error', e) : tink.web.Response); };
    
    var funcArgs:Array<FunctionArg> = [{
      name: '__depth__',
      type: macro : Int,
    }];
      
    var func:Function = 
      switch f.type.reduce() {
        case TFun(args, r):
          
          var callArgs = new Array<Expr>();
          var futures = new Array<Var>();
          
          function queryParser(type, e, body) {
            var parser = QueryParserBuilder.build(type, f.pos, body).toString().asTypePath();
            return macro @:pos(f.pos) new $parser($e);
          }
          
          for (a in args)
            switch a.name {
              case 'query':
                
                if (f.meta.has(':sub'))
                  f.pos.warning('Relying on query for subrouting risks leading to conflicts with the subroute\'s logic');
                  
                callArgs.push(macro ${queryParser(a.t, macro query.iterator(), false)}.parse());
                
              case 'body':
                
                if (f.meta.has(':sub'))
                  f.pos.warning('Relying on body for subrouting risks leading to conflicts with the subroute\'s logic');
                
                //TODO: give warnings when verb does not have a body
                
                var ct = a.t.toComplex();
                
                function fail(msg:String)
                  return macro tink.core.Future.sync(tink.core.Outcome.Failure(new tink.core.Error(UnprocessableEntity, $v{msg})));
                
                futures.push({
                  name: a.name,
                  type: null,
                  expr: 
                    macro @:pos(f.pos) switch this.request.header.get('content-type') {
                      case ['application/json']:
                        switch this.request.body {
                          case Plain(src):
                            src.all() >> function (body:haxe.io.Bytes) return new tink.json.Parser<$ct>().tryParse(body.toString());                     
                          default:
                            ${fail('Invalid JSON')};
                        }
                      case ['application/x-www-form-urlencoded' | 'multipart/form-data']:
                        this.bodyParts >> function (parts:tink.http.StructuredBody) return ${queryParser(a.t, macro @:pos(f.pos) parts.iterator(), true)}.tryParse();
                      case v:
                        
                        tink.core.Future.sync(tink.core.Outcome.Failure(new tink.core.Error(UnprocessableEntity, switch v {
                          case []: 'Unspecified Content-Type';
                          case [v]: 'Unknown Content-Type ' + v;
                          case many: 'Duplicate Content-Type headers';
                        })));
                        
                    }
                });
                
                callArgs.push(macro @:pos(f.pos) body);
                
              case 'path':
                
                callArgs.push(macro @:privateAccess new Path(this.prefix.concat(this.path.slice(0, __depth__))));
              
              case 'context':
                
                callArgs.push(macro @:pos(f.pos) this);
                
              default:
                
                callArgs.push(macro @:pos(f.pos) $i{a.name});
                
                var ct = a.t.toComplex();
                
                switch (macro @:pos(f.pos) ((null : tink.web.Stringly) : $ct)).typeof() {
                  case Failure(e):
                    f.pos.error('Routing cannot provide value for function argument ${a.name} of type ${a.t.toString()}');
                  default:
                }
                
                funcArgs.push({
                  //type: macro : tink.web.Stringly,
                  type: ct,
                  name: a.name,
                  opt: a.opt,
                });
            }
            
            
          var call = macro @:pos(f.pos) this.target.$fName($a{callArgs});
          
          if (futures.length > 0) {
            
            //call = ret(call, r);
            
            call = macro @:pos(call.pos) ${mkResponse(wrap(call, r))};
            
            futures.reverse();
            
            for (f in futures) {
              var name = f.name;
              call = macro @:pos(f.expr.pos) $i{name} >> function ($name) return $call;
            }
            
            futures.reverse();
            
            call = macro $restrict.respond(function () {
              ${EVars(futures).at()};
              return $call;
            });
            
            call = @:pos(call.pos) macro return $call;
            
            {
              args: funcArgs,
              ret: null,
              expr: call,
            }
          }
          else 
            {
              args: funcArgs,
              ret: null,
              expr: ret(call, r),
            }
        case v:
          
          {
            args: funcArgs,
            ret: null,
            expr: ret(macro @:pos(f.pos) this.target.$fName, v),
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
  
  function callHandler(verb:Expr, f:ClassField, m:MetadataEntry, handler:Handler, ?withRest = false) {
    var pos = m.pos;
    var uri:Url = switch m.params {
      case null | []: 
        f.name;
      case [v]: 
        pos = v.pos;
        v.getName().sure();
      case v: 
        v[1].reject('Not Implemented');
    }
    
    var parts = uri.path.parts();
    if (!withRest) {
      withRest = parts[parts.length - 1] == '*';
      
      if (withRest)
        parts.pop();      
    }
    
    var found = new Map();
    
    var patternArgs = [
      for (p in parts) {
        var p:String = p;
        if (p.charAt(0) == '$') {
          var name = p.substr(1);
          
          if (isSpecial(name))
            pos.error('Cannot use reserved name $name for captured variable');
            
          found[name] = true;
          macro @:pos(m.pos) $i{name}
        }
        else
          macro @:pos(m.pos) $v{p}
      }
    ]; 
    
    patternArgs.push(
      if (withRest) macro _
      else macro null
    );
                      
    var callArgs = [],
        guard = null;
    
    function capture(name:String, opt) {
      
      callArgs.push(macro $i{name});
      
      if (!opt) {
        var cond = macro $i{name} != null;
        
        guard = switch guard {
          case null: cond;
          default: macro $guard && $cond;
        }
      }
    }
    
    for (arg in handler.func.args.slice(1))
      switch [arg.opt == true, found[arg.name] == true] {
        case [false, false]:
          pos.error('Route does not capture required variable ${arg.name}');
        case [true, false]:
        case [opt, true]:
          capture(arg.name, opt);
      }
      
    //TODO: find unused captured vars
    callArgs.unshift(macro @:pos(m.pos) $v{patternArgs.length-1});
    return {
      pattern: patternArgs, 
      expr: macro @:pos(m.pos) $i{handler.name}($a{callArgs}), 
      guard: guard,
    }
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
    
    var restrict =     
      switch target {
        case TInst(_.get().meta => meta, _):
          getRestriction(meta);
        default: [];
      }
      
    for (f in target.getFields().sure()) {
            
      var meta = f.meta.get();
      
      switch [hasRoute(f), [for (m in meta) if (m.name == ':sub') m]] {
        
        case [true, []]:
          
          var handler = makeHandler(f, restrict);
          
          for (m in meta)
            switch metas[m.name] {
              
              case null:
              case verb:
                
                var call = callHandler(verb, f, m, handler);
                
                add(verb, call.pattern, call.expr, call.guard);
                
            }
          
        case [true, v]:
          
          f.pos.error('cannot have both routing and subrouting on the same field');
          
        case [false, []]:
          
        case [false, sub]:
          
          var handler = makeHandler(f, restrict, function (e, t) {
            var subType = switch t {
              case TAbstract(_.get() => {name: 'Future'}, [TEnum(_.get() => {name: 'Outcome'}, [t, _])])
              | TEnum(_.get() => {name: 'Outcome'}, [t, _])
              | TAbstract(_.get() => {name: 'Future'}, [t]): t;
              default: t;
            }
            var path = buildContext(user, subType).path;
            return macro @:pos(e.pos) SubRoute.of($e).route(function (target) {
              return new $path(this.session, target, this.request, function (_) return this.fallback(this), this.prefix.length + __depth__).route();
            });
          });
          
          for (m in sub) {
            var call = callHandler(macro _, f, m, handler, true);
            add(macro _, call.pattern, call.expr, call.guard);
          }
      }
      
    }
    
    for (c in cases)
      while (c.pattern.length < max)
        c.pattern.push(c.pattern[c.pattern.length - 1]);
    
    var switchTarget = [macro this.request.header.method];
    
    for (i in 0...max - 1)
      switchTarget.push(macro this.path[$v{i}]);
    
    var body = ESwitch(
      switchTarget.toArray(),
      [for (c in cases) {
        values: [macro @:pos(c.response.pos) $a{c.pattern}],
        guard: c.guard,
        expr: c.response,
      }],
      {
        var ret = macro fallback(this);
        for (c in cases)
          if (c.guard == null && c.pattern.filter(function (e) return !e.isWildcard()).length == 0) {
            ret = null;
            break;
          }
        ret;
      }
    ).at();  
    
    var f = (macro class {
      
      public function route():Response 
        return $body;
      
    }).fields;
    
    for (f in f)
      this.fields.push(f);
  }
  
  static public function getTypes(name, length)
    return 
      switch Context.getLocalType() {
        case TInst(_.toString() == name => true, v) if (v.length == length):
          Success(v);
        default:
          Failure('assert');
      }
      
  static public function getType(name) 
    return getTypes(name, 1).map(function (x) return x[0]);
      
  
  static public function buildContext(user:Type, target:Type):{ type:Type, path:TypePath } {
    //TODO: add cache
    var counter = counter++;
    var name = 'RoutingContext$counter';
    var decl = {
      
      var user = user.toComplex(),
          target = target.toComplex();
          
      macro class $name extends RoutingContext<$user, $target> {
      }
    }
    
    decl.fields = decl.fields.concat(new Routing(user, target).fields);
    
    return {
      type: declare(decl),
      path: fullName(name).asTypePath(),
    }
  }
  
  static function fullName(name:String)
    return '$PACK.$name';
  
  static function declare(t:TypeDefinition):Type {
    var name = fullName(t.name);
    Context.defineModule(name, [t]);
    return Context.getType(name);
  }
  
  static var counter = 0;
  
  static function buildRouter():Type {
    
    switch getTypes('tink.web.Router', 2) {
      case Success([user, target]):
        
        var counter = counter++;
        var router = 'Router$counter';
        
        var ctx = buildContext(user, target).path;
        
        var user = user.toComplex(),
            target = target.toComplex();
            
        var cl = macro class $router {
          
          public inline function new() this = $v{counter};
          
          public function route(session:tink.web.Session<$user>, target:$target, request:Request, ?fallback, depth = 0) 
            return 
              new $ctx(session, target, request, fallback, depth).route();
        }
        
        cl.kind = TDAbstract(macro : Int);
        
        return declare(cl);
        
      case v: 
        
        v.sure();
        return null;
    }
  }
  
}