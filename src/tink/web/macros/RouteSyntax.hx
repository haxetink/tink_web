package tink.web.macros;

import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.ds.Option;
import tink.url.Portion;
import tink.http.Method;
import tink.web.macros.Route;

using tink.MacroApi;
using tink.CoreApi;
using Lambda;

enum RoutePayload {
  Empty;
  Mixed(separate:Array<Field>, compound:Array<Named<Type>>, sum:ComplexType);
  SingleCompound(name:String, type:Type);
}

class RouteSyntax {
  
  static var metas = {
    var ret = [for (m in [GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE]) ':$m'.toLowerCase() => Some(m)];
    
    ret[':all'] = None;
    
    ret;
  }  
  
  static function getCaptured(a:Iterable<RoutePathPart>)
    return [for (p in a) switch p {
      case PConst(_): continue;
      case PCapture(name): name;
    }];
  
  static function hasRoute(f:ClassField) {
    for (m in metas.keys())
      if (f.meta.has(m)) return true;
    return false;
  }  
  
  static var reserved = [
    'user' => AUser,
    'query' => AParam.bind(_, PQuery, PCompound),
    'body' => AParam.bind(_, PBody, PCompound),
    'header' => AParam.bind(_, PHeader, PCompound),    
  ];
  
  static var paramPositions = [
    'query' => AParam.bind(_, PQuery, _),
    'body' => AParam.bind(_, PBody, _),
    'header' => AParam.bind(_, PHeader, _),
  ];
  
  static function getPath(fieldName:String, sig:RouteSignature, m:MetadataEntry):RoutePath 
    return switch m.params {
      case []: 
        
        getPath(fieldName, sig, { pos: m.pos, name: m.name, params: [fieldName.toExpr(m.pos)] });
        
      case [v]: 
        //TODO: check path against signature
        var sigMap = [for (s in sig) s.name => s];
        var url = tink.Url.parse(v.getString().sure());
        
        var parts = url.path.parts();
        
        var last = parts[parts.length - 1].raw;
        
        function capture(name) 
          return 
            switch sigMap[name] {
              case null | { kind: ACapture }: name;
              default: 
                m.pos.error(
                  'Cannot capture `$name` in URI because ' + 
                    if (reserved.exists(name)) 
                      'it is reserved';
                    else
                      'its role was already determined in a @:params directive'
                );
            }
        
        var rest = 
          if (last == null) RNotAllowed;//TODO: report issue: having a null-case runs into a null-pointer exception because of the split below
          else switch last {                
            case '*': 
              parts.pop();
              RIgnore;
            case _.split('*') => ['', v]: 
              parts.pop();
              RCapture(capture(v));
            default:
              RNotAllowed;
          }
          
        if (!metas.exists(m.name)) {
          switch rest {
            case RCapture(_):
              v.reject('cannot capture path rest in @${m.name}');
            case RIgnore:
              v.pos.warning('Path rest is always allowed for @${m.name}');
            default:
              rest = RIgnore;
          }
          
        }
        
        function part(of:Portion) 
          return switch of {
            case _.raw.split('$') => ['', name]:
              PCapture(capture(name));
            default:
              PConst(of);
          }
          
        var parts = [for (p in parts) part(p)],
            query = [for (q in url.query) q.name => part(q.value)];    
            
        var optional = new Map();
        var captured = [for (a in sig) switch a.kind {
          case ACapture: 
            if (a.optional)
              optional[a.name] = true;
            a.name;
          default: 
            continue;
        }];
        
        var surplus = [for (c in getCaptured(parts).concat(getCaptured(query))) if (!captured.remove(c)) c];
        var missing = [for (c in captured) if (!optional[c]) c];
        
        {
          pos: v.pos,
          parts: parts,
          query: query,
          deviation: { surplus: surplus, missing: missing, },
          rest: rest,
        }
        
      case v: 
        v[1].reject('only one path per route allowed');
    }
    
  static function liftResponse(t:Type, pos:Position) {
    var ct = t.toComplex();
    return (macro @:pos(pos) {
      
      function get<A>(p:tink.core.Promise<A>):A
        throw 'whatever';
        
      get((null : $ct));
    }).typeof().sure();
  }
    
  static function fieldType(f:ClassField)
    return 
      switch f.type.reduce() {
        case TFun(args, ret):
          
          var argsByName = [for (a in args) a.name => { arg: a, special: ACapture } ];
          
          function addSpecial(pos:Position, name:String, special)
            switch argsByName[name] {
              case null: pos.error('unknown parameter `$name`');
              case v:
                if (v.special == ACapture)
                  v.special = special(v.arg.t);
                else
                  pos.error('duplicate parameter specification for `$name`');
            }
            
          for (a in args)
            switch reserved[a.name] {
              case null:
                if (a.t.getID() == 'tink.web.routing.Context')
                  addSpecial((macro null).pos, a.name, function (_) return AContext);
              case v:
                addSpecial(f.pos, a.name, v);
            }  
          
          for (entry in f.meta.extract(':params'))
            for (p in entry.params)
              switch p {
                case macro $i{name} in $i{pos} if (paramPositions.exists(pos)):
                  
                  if (reserved.exists(name))
                    p.reject('`$name` is reserved');
                    
                  addSpecial(p.pos, name, paramPositions[pos].bind(_, PSeparate));
                  
                case macro $i{name} = $i{pos} if (paramPositions.exists(pos)):
                  
                  if (reserved.exists(name))
                    p.reject('`$name` is reserved');
                    
                  addSpecial(p.pos, name, paramPositions[pos].bind(_, PCompound));
                  
                default:
                  p.reject('Should be `<name> in (query|header|body)` or  `<name> = (query|header|body)`');
              }
              
          {
            args: [for (a in args) {
              name: a.name, 
              type: a.t,
              kind: argsByName[a.name].special,
              optional: a.opt,
            }],
            ret: ret,
          }
        case t:
          { args:[], ret: t };
      }
      
  static function checkVariants<V:Variant>(pos:Position, variants:Iterable<V>) {
    
    function warn(prefix, pos:Position, args:Array<String>) {
      var names = switch args {
        case [single]: '`$single`';
        default: 
          's `${args.slice(0, -1).join("`, `")}` and `${args[args.length - 1]}`';
      }
      pos.warning(prefix + names);
    }
    
    if (!Lambda.exists(variants, function (v) return v.path.deviation.missing.length == 0)) {
      pos.warning('All defined routes are incomplete');
      for (v in variants)
        warn('Route does not capture argument', v.path.pos, v.path.deviation.missing);
    }
      
    if (!Lambda.exists(variants, function (v) return v.path.deviation.surplus.length == 0)) {
      pos.warning('All defined routes are overdetermined');
      for (v in variants)
        warn('Route captures surplus portion', v.path.pos, v.path.deviation.surplus);
    }
      
  }
  
  static public function getPayload(route:Route, loc:ParamLocation):RoutePayload {
    var compound = new Array<Named<Type>>(),
        separate = new Array<Field>();
        
    for (arg in route.signature) 
      switch arg.kind {
        case AParam(t, _ == loc => true, kind):
          switch kind {
            case PCompound:
              compound.push(new Named(arg.name, t));
            case PSeparate:
              separate.push({
                name: arg.name,
                pos: route.field.pos,
                kind: FVar(t.toComplex()),
              });     
          }
        default:
    }
    
    var locName = loc.getName().substr(1).toLowerCase();    
    
    return 
      switch [compound, separate] {
        case [[], []]: 
          
          Empty;
          
        case [[v], []]: 
          
          SingleCompound(v.name, v.value);
          
        case [[], v]: 
        
          Mixed(separate, compound, TAnonymous(separate));
          
        default:
          //trace(TAnonymous(separate).toString());
          var fields = separate.copy();
          
          for (t in compound)
            switch t.value.reduce().toComplex() {
              case TAnonymous(f):
                for (f in f)
                  fields.push(f);
              default:
                route.field.pos.error('If multiple types are defined for $locName then all must be anonymous objects');
            }          
            
          Mixed(separate, compound, TAnonymous(fields));
      }
  }
  
  static public function read(t:Type, consumes:Array<MimeType>, produces:Array<MimeType>) {
    
    var ret = new Array<Route>();
    switch t {
      case TInst(_.get().meta => m, _) | TAbstract(_.get().meta => m, _) | TType(_.get().meta => m, _): 
        consumes = MimeType.fromMeta(m, 'consumes', consumes);
        produces = MimeType.fromMeta(m, 'produces', produces);
      default:
    }
    //consumes = MimeType.fromMeta(t.get
    for (f in t.getFields().sure()) {
      
      function mimes(name, init)
        return Lazy.ofFunc(MimeType.fromMeta.bind(f.meta, name, init));
      
      var meta = f.meta.get(),
          type = Lazy.ofFunc(fieldType.bind(f)),
          produces = mimes('produces', produces),
          consumes = mimes('consumes', consumes);
      
      var result = type.map(function (x) return liftResponse(x.ret, f.pos)),
          signature = type.map(function (x) return x.args);
          
      function path(m:MetadataEntry)
        return getPath(f.name, signature, m);
      
      function add(kind:RouteKind) {
        switch kind {
          case KCall(call): 
            checkVariants(f.pos, call.variants);
          case KSub(sub): 
            for (arg in signature.get())
              switch arg.kind {
                case AParam(_, PBody, _):
                  sub.variants[0].path.pos.error('Sub routes may not have a body');
                default:
              }
            checkVariants(f.pos, sub.variants);
        }
        ret.push({
          field: f,
          kind: kind,
          signature: signature,
          consumes: consumes,
          produces: produces,
        });
      }
      
      switch [hasRoute(f), [for (m in meta) if (m.name == ':sub') m]] {
        
        case [true, []]:
          
          add(KCall( {
            variants: [for (m in meta) 
              switch metas[m.name] {
                case null: continue;
                case v: { method: v, path: path(m), }
              }
            ],
            response: switch result.isSubTypeOf(haxe.macro.Context.getType('tink.web.routing.Response')) {
              case Success(_): ROpaque(result);
              default: RData(result);
            }
          }));
          
        case [true, v]:
          
          f.pos.error('cannot have both routing and subrouting on the same field');
          
        case [false, []]:
          
        case [false, sub]:
          
          add(KSub({
            variants: [for (m in sub) { path: path(m) }],
            target: result,
          }));
          
      }
    }
    
    return ret;
  }

}