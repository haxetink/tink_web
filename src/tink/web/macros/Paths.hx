package tink.web.macros;

#if macro
import tink.http.Method;
import tink.url.Portion;
import tink.web.macros.Arguments;

class Paths {

  public static var metas = {
    var ret = [for (m in [GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE]) ':$m'.toLowerCase() => Some(m)];
    ret[':all'] = None;
    ret;
  }

  var list:Array<Path>;

  public function new(fieldName:String, args:Array<{t:Type, name:String, opt:Bool}>, meta:MetaAccess) {
    var isSub = false;
    var isCall = false;

    list = [for(meta in meta.get()) {

      function checkConflict(conflict) if(conflict) meta.pos.error('Cannot have both routing and subrouting on the same field');

      switch meta.name {
        case ':sub':
          isSub = true;
          checkConflict(isCall);
          Path.make(Sub, fieldName, args, meta);
        case metas[_] => null:
          continue;
        case metas[_] => v:
          isCall = true;
          checkConflict(isSub);
          Path.make(Call(v), fieldName, args, meta);
      }
    }];
  }

  public inline function iterator() return list.iterator();

  /**
   * Return true if the specified capture exists in all declared paths
   * @param kind
   */
  public function hasCapture(access:ArgAccess) {
    for(path in list)
      switch path.getCapture(access) {
        case Some(_): // ok
        case None: return false;
      }
    return true;
  }
}


@:structInit
class Path {
  public var expr(default, null):Expr;
  public var parts(default, null):Array<PathPart>;
  public var query(default, null):Map<String, PathPart>;
  public var rest(default, null):PathRest;
  public var kind(default, null):PathKind;
  public var deviation(default, null):{
    var surplus(default, null):Array<String>;
    var missing(default, null):Array<String>;
  }
  public var pos(default, null):Position;

  public static function make(kind:PathKind, fieldName:String, args:Array<{t:Type, name:String, opt:Bool}>, m:MetadataEntry):Path {
    return switch m.params {
      case []:

        make(kind, fieldName, args, { pos: m.pos, name: m.name, params: [fieldName.toExpr(m.pos)] });

      case [v]:
        var url = tink.Url.parse(v.getString().sure());

        var parts = url.path.parts();

        var last = parts[parts.length - 1].raw;

        var rest =
          if(m.name == ':sub')
            RIgnore;
          else switch last {
            case null:
              RNotAllowed;
            case '*':
              parts.pop();
              RIgnore;
            // case _.split('*') => ['', v]:
            //   parts.pop();
            //   RCapture(capture(v));
            default:
              RNotAllowed;
          }

        // TODO: is this still needed?
        // if (!Route.metas.exists(m.name)) {
        //   switch rest {
        //     case RCapture(_):
        //       v.reject('cannot capture path rest in @${m.name}');
        //     case RIgnore:
        //       v.pos.warning('Path rest is always allowed for @${m.name}');
        //     default:
        //       rest = RIgnore;
        //   }
        // }

        function part(of:Portion)
          // TODO: support drilled ('/${obj.foo}') and mixed ('/$obj:patch')
          return switch of {
            case _.raw.split('$') => ['', name]:
              PCapture(Plain(name));
            default:
              PConst(of);
          }

        var parts = [for (p in parts) part(p)],
            query = [for (q in url.query) q.name => part(q.value)];


        // TODO: is this still needed?
        // var optional = new Map();
        // var captured = [for (a in sig.args) switch a.kind {
        //   case ACapture:
        //     if (a.optional)
        //       optional[a.name] = true;
        //     a.name;
        //   default:
        //     continue;
        // }];

        // TODO:
        // var surplus = [for (c in getCaptured(parts).concat(getCaptured(query))) if (!captured.remove(c)) c];
        // var missing = [for (c in captured) if (!optional[c]) c];
        var surplus = [];
        var missing = [];

        {
          kind: kind,
          expr: v,
          pos: v.pos,
          parts: parts,
          query: query,
          deviation: { surplus: surplus, missing: missing },
          rest: rest,
        }

      case v:
        v[1].reject('only one path per route allowed');
    }
  }

  public function getCapture(access:ArgAccess):Option<PathPart> {
    for(part in parts)
      switch [access, part] {
        case [Plain(n1), PCapture(Plain(n2))] if(n1 == n2): return Some(part);
        case [Drill(n1, f1), PCapture(Drill(n2, f2))] if(n1 == n2 && f1 == f2): return Some(part);
        case _:
      }
    return None;
  }
}

enum PathKind {
  Sub;
  Call(method:Option<Method>);
}

enum PathRest {
  RIgnore;
  // RCapture(name:String); // TODO: re-enable this
  RNotAllowed;
}

enum PathPart {
  PConst(s:Portion);
  PCapture(access:ArgAccess);
  // PMixed(arr:Array<PathPart>); // TODO: support some kind of mixed/advanced capture, see https://github.com/haxetink/tink_web/issues/26
}
#end