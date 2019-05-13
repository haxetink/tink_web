package tink.web.macros;

import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
import tink.web.macros.Parameters;

using tink.CoreApi;
using tink.MacroApi;
using Lambda;

// hold information extracted from the function argument list
class Arguments {
  var list:Array<RouteArg> = [];
  static var CONTEXT:Lazy<Type> = Context.getType.bind('tink.web.routing.Context');
  
  public function new(args:Array<{t:Type, opt:Bool, name:String}>, paths:Paths, params:Parameters, pos:Position) {
    for(a in args) list.push({
      name: a.name,
      type: a.t,
      optional: a.opt,
      kind: switch [a.name, a.t.reduce()] {
        case [_, _] if(a.t.unifiesWith(CONTEXT)):
          AKSingle(ATContext);
        case ['user', _] if(a.name == 'user'):
          AKSingle(ATUser(a.t));
        case ['body', _.getID() => 'haxe.io.Bytes' | 'String']:
          AKSingle(ATParam(PKBody(None)));
        case ['query' | 'header' | 'body', t = TAnonymous(_)]:
          anon(t, function(name) return ATParam(Parameters.LOCATION_FACTORY[a.name](name)));
        case [name, TAnonymous(_.get() => {fields: fields})]:
          AKObject([for(field in fields) {
            name: field.name,
            type: field.type,
            target: getArgTarget(paths, params, Drill(name, field.name), a.opt, pos),
          }]);
        case [name, _]:
          AKSingle(getArgTarget(paths, params, Plain(name), a.opt, pos));
      }
    });
  }
  
  public inline function iterator() return list.iterator();
  
  static function getArgTarget(paths:Paths, params:Parameters, access:ArgAccess, optional:Bool, pos:Position) {
    return switch [paths.hasCapture(access), params.get(access)] {
      case [true, Some(param)]:
        param.source.pos.error('`${stringifyArgAccess(access)}` is both captured in path and specified as parameter with @:params(${param.source.toString()})');
      case [false, Some(param)]:
        ATParam(param.kind);
      case [true, None]:
        ATCapture;
      case [false, None]:
        if(!optional) {
          // trace(access);
          // for(p in params) trace(p.source.toString(), p.access, p.kind);
          // for(p in paths) trace(p.parts);
          pos.error('`${stringifyArgAccess(access)}` is not used. Please specify its use with the @:params metadata or capture it in the route paths');
        } else {
          ATCapture;
        }
    }
  }
  
  static function stringifyArgAccess(access:ArgAccess) {
    return switch access {
      case Plain(name): name;
      case Drill(name, field): '$name.$field';
    }
  }
  
  
  static function anon(type:Type, factory:String->ArgTarget):ArgKind {
    return switch type {
      case TAnonymous(_.get() => {fields: fields}):
        AKObject([for(field in fields) {
          name: field.name,
          type: field.type,
          target: factory(switch field.meta.extract(':name') {
            case [{params: [macro $v{(name:String)}]}]: name;
            case [{params: _, pos: pos}]: pos.error('@:name meta should contain exactly one string literal parameter');
            case _: field.name;
          }),
        }]);
      case _:
        throw 'unreachable';
    }
  }
}


typedef RouteArg = {
  var name(default, null):String;
  var type(default, null):Type;
  var optional(default, null):Bool;
  var kind(default, null):ArgKind;
}

enum ArgAccess {
  Plain(name:String);
  Drill(name:String, field:String);
}

enum ArgKind {
  AKSingle(target:ArgTarget);
  AKObject(fields:Array<{name:String, type:Type, target:ArgTarget}>);
}

enum ArgTarget {
  ATContext;
  ATUser(type:Type);
  ATSession(type:Type);
  ATCapture;
  ATParam(kind:ParamKind);
}
