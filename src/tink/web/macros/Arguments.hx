package tink.web.macros;

#if macro
import tink.web.macros.Parameters;

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
          AKSingle(a.opt, ATContext);
        case ['user', _] if(a.name == 'user'):
          AKSingle(a.opt, ATUser(a.t));
        case ['query' | 'header' | 'body', t = TAnonymous(_)]:
          anon(a.opt, t, function(name) return ATParam(Parameters.LOCATION_FACTORY[a.name](name)));
        case ['body', _]:
          AKSingle(a.opt, ATParam(PKBody(None)));
        case [name, TAnonymous(_.get() => {fields: fields})]:
          AKObject(a.opt, [for(field in fields) {
            name: field.name,
            type: field.type,
            optional: field.meta.has(':optional'),
            target: getArgTarget(paths, params, Drill(name, field.name), a.opt, pos),
          }]);
        case [name, _]:
          AKSingle(
            a.opt,
            getArgTarget(paths, params, Plain(name), a.opt, pos)
          );
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
        if(!optional)
          tryQuery(paths, access, pos);
        else
          ATCapture;
    }
  }

  static function tryQuery(paths:Paths, access:ArgAccess, pos:Position) {
    var access = stringifyArgAccess(access);
    for (p in paths)
      if (!Lambda.exists(p.query, v -> switch v {
        case PCapture(v): stringifyArgAccess(v) == access;
        case PConst(_): false;
      }))
        p.pos.error('${p.expr.toString()} does not capture required parameter `$access`. Please specify its use with the @:params metadata or capture it.');

    return ATCapture;
  }

  static function stringifyArgAccess(access:ArgAccess) {
    return switch access {
      case Plain(name): name;
      case Drill(name, field): '$name.$field';
    }
  }


  static function anon(optional:Bool, type:Type, factory:String->ArgTarget):ArgKind {
    return switch type {
      case TAnonymous(_.get() => {fields: fields}):
        AKObject(optional, [for(field in fields) {
          name: field.name,
          type: field.type,
          optional: field.meta.has(':optional'),
          target: factory(Parameters.getParamName(field)),
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
  AKSingle(optional:Bool, target:ArgTarget);
  AKObject(optional:Bool, fields:Array<{name:String, type:Type, optional:Bool, target:ArgTarget}>);
}

enum ArgTarget {
  ATContext;
  ATUser(type:Type);
  ATSession(type:Type);
  ATCapture;
  ATParam(kind:ParamKind);
}
#end