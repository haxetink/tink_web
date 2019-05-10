package tink.web.macros;

import tink.http.Method;
import tink.web.macros.Variant;
import tink.web.macros.RouteSignature;
import tink.web.macros.RouteResult;
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
  public var restricts(default, null):Array<Expr>;
  
  public function new(f, consumes, produces) {
    field = f;
    signature = new RouteSignature(f);
    switch [getCall(f, signature), getSub(f, signature)] {
      case [[], []]:
        f.pos.error('No routes on this field'); // should not happen actually
      case [call, []]:
        kind = KCall({
          variants: call,
          statusCode: 
            switch field.meta.extract(':statusCode') {
              case []:
                macro 200;
              case [{params: [v]}]:
                v;
              case [v]:
                v.pos.error('@:statusCode must have one argument exactly');
              case v:
                v[1].pos.error('Cannot have multiple @:statusCode directives');
            },
          headers:
            [for(meta in field.meta.extract(':header'))
              switch meta {
                case {params: [name, value]}:
                  new NamedWith(name, value);
                case _:
                  meta.pos.error('@:header must have two arguments exactly');
              }
            ],
          html: 
            switch field.meta.extract(':html') {
              case []:
                None;
              case [{ pos: pos, params: [v] }]:
                Some(v);
              case [v]:
                v.pos.error('@:html must have one argument exactly');
              case v:
                v[1].pos.error('Cannot have multiple @:html directives');
            }
        });
      case [[], sub]:
        kind = KSub(sub);
      case [_, _]:
        f.pos.error('Cannot have both routing and subrouting on the same field');
    }
    this.consumes = MimeType.fromMeta(f.meta, 'consumes', consumes);
    this.produces = MimeType.fromMeta(f.meta, 'produces', produces);
    
    restricts = getRestricts([field.meta]);
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
  
  // TODO: move this to somewhere
  public static function getRestricts(meta:Array<MetaAccess>):Array<Expr> {
    return [for(meta in meta) for (m in meta.extract(':restrict'))
      switch m.params {
        case [v]:
          v;
        case _:
          m.pos.error('@:restrict must have one parameter');
      }
    ];
  }
}

enum RouteKind {
  KSub(variants:Array<Variant>);
  KCall(call:Call);
}

typedef Call = {
  variants:Array<CallVariant>,
  statusCode:Expr,
  headers:Array<NamedWith<Expr, Expr>>,
  html:Option<Expr>,
}

enum RoutePayload {
  Empty;
  Mixed(separate:Array<Field>, compound:Array<Named<Type>>, sum:ComplexType);
  SingleCompound(name:String, type:Type);
}