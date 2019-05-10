package tink.web.macros;

import haxe.macro.Expr;
import haxe.macro.Type;

using tink.MacroApi;

class RouteSignature {
  
  public static var reserved = [
    'user' => AUser,
    'query' => AParam.bind(_, PQuery, PCompound),
    'body' => AParam.bind(_, PBody, PCompound),
    'header' => AParam.bind(_, PHeader, PCompound),    
  ];
  
  public static var paramPositions = [
    'query' => AParam.bind(_, PQuery, _),
    'body' => AParam.bind(_, PBody, _),
    'header' => AParam.bind(_, PHeader, _),
  ];
  
  public var args(default, null):Array<RouteArg>;
  public var result(default, null):RouteResult;
  
  public function new(f:ClassField) {
    switch f.type.reduce() {
      case TFun(args, ret):
        var argsByName = [for (a in args) a.name => { arg: a, special: ACapture } ];
        
        function addSpecial(pos:Position, name:String, special:Type->RouteArgKind)
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
            
        this.args = [for (a in args) {
          name: a.name, 
          type: a.t,
          kind: argsByName[a.name].special,
          optional: a.opt,
        }];
        this.result = new RouteResult(lift(ret, f.pos));
      case t:
        this.args = [];
        this.result = new RouteResult(lift(t, f.pos));
    }
  }
  
  static function lift(t:Type, pos:Position) {
    var ct = t.toComplex();
    return (macro @:pos(pos) {
      function get<A>(p:tink.core.Promise<A>):A throw 'whatever';
      get((null : $ct));
    }).typeof().sure();
  }
}

typedef RouteArg = {
  var name(default, null):String;
  var type(default, null):Type;
  var optional(default, null):Bool;
  var kind(default, null):RouteArgKind;
}


enum RouteArgKind {
  AContext;
  ACapture;//note that this may come from path *or* query string
  AParam(type:Type, loc:ParamLocation, kind:ParamKind);
  AUser(type:Type);
  ASession(type:Type);
}

enum ParamKind {
  PSeparate;
  PCompound;
}

enum ParamLocation {
  PQuery;
  PBody;
  PHeader;
}