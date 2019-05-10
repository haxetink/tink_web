package tink.web.v2;

import tink.http.Method;
import tink.web.v2.Variant;
import tink.web.v2.RouteSignature;
import tink.web.v2.RouteResult;
import haxe.ds.Option;
import haxe.macro.Type;
import haxe.macro.Expr;

using tink.CoreApi;
using tink.MacroApi;

class Route {
  
  public static var metas = {
    var ret = [for (m in [GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE]) ':$m'.toLowerCase() => Some(m)];
    ret[':all'] = None;
    ret;
  }  
  
  public var field(default, null):ClassField;
  public var kind(default, null):RouteKind;
  public var signature(default, null):RouteSignature;
  public var consumes(default, null):Array<MimeType>;
  public var produces(default, null):Array<MimeType>;
  
  public function new(f, consumes, produces) {
    field = f;
    signature = new RouteSignature(f);
    switch [getCall(f, signature), getSub(f, signature)] {
      case [[], []]: f.pos.error('No routes on this field'); // should not happen actually
      case [call, []]: kind = KCall(call);
      case [[], sub]: kind = KSub(sub);
      case [_, _]: f.pos.error('Cannot have both routing and subrouting on the same field');
    }
    this.consumes = MimeType.fromMeta(f.meta, 'consumes', consumes);
    this.produces = MimeType.fromMeta(f.meta, 'produces', produces);
  }
  
  public function getPayload(loc:ParamLocation):RoutePayload {
    var compound = new Array<Named<Type>>(),
        separate = new Array<Field>();
        
    for (arg in signature.args) 
      switch arg.kind {
        case AParam(t, _ == loc => true, kind):
          switch kind {
            case PCompound:
              compound.push(new Named(arg.name, t));
            case PSeparate:
              separate.push({
                name: arg.name,
                pos: field.pos,
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
                field.pos.error('If multiple types are defined for $locName then all must be anonymous objects');
            }          
            
          Mixed(separate, compound, TAnonymous(fields));
      }
  }
  
  public static function hasWebMeta(f:ClassField) {
    if (f.meta.has(':sub')) return true;
    for (m in metas.keys()) if (f.meta.has(m)) return true;
    return false;
  }
  
  public static function getCall(f:ClassField, sig):Array<CallVariant> {
    return [for(m in f.meta.get()) {
        switch metas[m.name] {
          case null: continue;
          case v: { method: v, path: RoutePath.make(f.name, sig, m) }
        }
      }
    ];
  }
  
  public static function getSub(f:ClassField, sig):Array<Variant> {
    return [for(m in f.meta.extract(':sub')) { path: RoutePath.make(f.name, sig, m) }];
  }
}

enum RouteKind {
  KSub(variants:Array<Variant>);
  KCall(variants:Array<CallVariant>);
}

enum RoutePayload {
  Empty;
  Mixed(separate:Array<Field>, compound:Array<Named<Type>>, sum:ComplexType);
  SingleCompound(name:String, type:Type);
}