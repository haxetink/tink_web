package tink.web.macros;

import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;

using tink.CoreApi;
using tink.MacroApi;
using Lambda;
class RouteSignature {
  
  static var CONTEXT:Lazy<Type> = Context.getType.bind('tink.web.routing.Context');
  
  // public static var reserved = [
  //   'user' => AUser,
  //   'query' => AParam.bind(_, PQuery, PCompound),
  //   'body' => AParam.bind(_, PBody, PCompound),
  //   'header' => AParam.bind(_, PHeader, PCompound),    
  // ];
  
  // public static var paramPositions = [
  //   'query' => AParam.bind(_, PQuery, _),
  //   'body' => AParam.bind(_, PBody, _),
  //   'header' => AParam.bind(_, PHeader, _),
  // ];
  
  public var paths(default, null):Paths;
  public var params(default, null):Parameters;
  public var args2(default, null):Arguments;
  public var result(default, null):RouteResult;
  
  // public var args(default, null):Array<RouteArg>;
  
  public function new(f:ClassField) {
    switch f.type.reduce() {
      case TFun(args, ret):
        
        paths = new Paths(f.name, args, f.meta);
        params = new Parameters(f.meta, [for(a in args) a.name => a.t]);
        args2 = new Arguments(args, paths, params, f.pos);
        
        // var argsByName = [for (a in args) a.name => { arg: a, special: ACapture } ];
        
        // function addSpecial(pos:Position, name:String, special:Type->RouteArgKind)
        //   switch argsByName[name] {
        //     case null: pos.error('unknown parameter `$name`');
        //     case v:
        //       if (v.special == ACapture)
        //         v.special = special(v.arg.t);
        //       else
        //         pos.error('duplicate parameter specification for `$name`');
        //   }
          
        // for (a in args)
        //   switch reserved[a.name] {
        //     case null:
        //       if (a.t.getID() == 'tink.web.routing.Context')
        //         addSpecial((macro null).pos, a.name, function (_) return AContext);
        //     case v:
        //       addSpecial(f.pos, a.name, v);
        //   }  
        
        // for (entry in f.meta.extract(':params'))
        //   for (p in entry.params)
        //     switch p {
        //       case macro $i{name} in $i{pos} if (paramPositions.exists(pos)):
                
        //         if (reserved.exists(name))
        //           p.reject('`$name` is reserved');
                  
        //         addSpecial(p.pos, name, paramPositions[pos].bind(_, PSeparate));
                
        //       case macro $i{name} = $i{pos} if (paramPositions.exists(pos)):
                
        //         if (reserved.exists(name))
        //           p.reject('`$name` is reserved');
                  
        //         addSpecial(p.pos, name, paramPositions[pos].bind(_, PCompound));
                
        //       default:
        //         // p.reject('Should be `<name> in (query|header|body)` or  `<name> = (query|header|body)`');
        //     }
        
        // this.args = [for (a in args) {
        //   name: a.name, 
        //   type: a.t,
        //   kind: argsByName[a.name].special,
        //   optional: a.opt,
        // }];
        this.result = new RouteResult(lift(ret, f.pos));
      case t:
        paths = new Paths(f.name, [], f.meta);
        params = new Parameters(f.meta, []);
        args2 = new Arguments([], paths, params, f.pos);
        // this.args = [];
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



// hold information extracted from the function argument list
class Arguments {
  var list:Array<RouteArg2> = [];
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
          target: factory(field.name), // TODO: support meta to alter the native name
        }]);
      case _:
        throw 'unreachable';
    }
  }
}


// hold information extracted from the @:params metadata
class Parameters {
  var params:Array<ParamMapping> = [];
  
  public static var LOCATION_FACTORY = [
    'query' => PKQuery,
    'body' => function(name) return PKBody(Some(name)),
    'header' => PKHeader,
  ];
  
  public function new(meta:MetaAccess, types:Map<String, Type>) {
    for (entry in meta.extract(':params'))
      for (p in entry.params) {
        
        function validate(name:String) {
          if (reserved(name)) p.reject('`$name` is reserved');
          if (!types.exists(name)) p.reject('`$name` does not appear in the function argument list');
        }
        
        function hasField(type:Type, name:String) {
          return switch type {
            case TAnonymous(_.get() => {fields: fields}): fields.exists(function(field) return field.name == name);
            case _: false;
          }
        } 
        
        function add(access, kind) params.push({source: p, access: access, kind: kind});
        
        switch p {
          case macro $i{name} in $i{pos = 'query' | 'header' | 'body'}:
            validate(name);
            add(Plain(name), LOCATION_FACTORY[pos](name));
            
          case macro $i{name} = $i{pos = 'query' | 'header' | 'body'}:
            validate(name);
            switch types[name].reduce() {
              case TAnonymous(_.get() => {fields: fields}):
                for(field in fields) add(Drill(name, field.name), LOCATION_FACTORY[pos](field.name));
              case _:
                p.reject('`$name` should be anonymous structure');
            }
            
          case macro $i{name} = $i{pos = 'query' | 'header' | 'body'}[$v{(native:String)}]:
            validate(name);
            add(Plain(name), LOCATION_FACTORY[pos](native));
            
          case macro $i{name}.$field in $i{pos = 'query' | 'header' | 'body'}:
            validate(name);
            if(!hasField(types[name], field)) p.reject('`$name` does not has field "$field"');
            add(Drill(name, field), LOCATION_FACTORY[pos](field));
            
          case macro $i{name}.$field = $i{pos = 'query' | 'header' | 'body'}[$v{(native:String)}]:
            validate(name);
            if(!hasField(types[name], field)) p.reject('`$name` does not has field "$field"');
            add(Drill(name, field), LOCATION_FACTORY[pos](native));
            
          default:
            p.reject('Invalid syntax for @:params, only the following are supported:
    @:params(<ident> in <query|header|body>)
    @:params(<ident> = <query|header|body>)
    @:params(<ident> = <query|header|body>["native"])
    @:params(<ident.field> in <query|header|body>)
    @:params(<ident.field> = <query|header|body>["native"])');
    
        }
      }
      
      checkForConflict();
  }
  
  public inline function iterator() return params.iterator();
  
  function checkForConflict() {
    var checked:Array<ParamMapping> = [];
    for(current in params) {
      for(prev in checked) {
        if(conflictAccess(prev.access, current.access))
          current.source.reject('Conflicting argument access with "${prev.source.toString()}"'); // TODO: print the actual enum in a human-friendly way
        if(conflictKind(prev.kind, current.kind))
          current.source.reject('Conflicting param kind with "${prev.source.toString()}"'); // TODO: print the actual enum in a human-friendly way
        checked.push(current);
      }
    }
  }
  
  static function conflictAccess(a1:ArgAccess, a2:ArgAccess) {
    return switch [a1, a2] {
      case [Plain(n1), Plain(n2)] | [Drill(n1, _), Plain(n2)] | [Plain(n1), Drill(n2, _)]: n1 == n2;
      case [Drill(n1, f1), Drill(n2, f2)]: n1 == n2 && f1 == f2;
    }
  }
  
  static function conflictKind(k1:ParamKind2, k2:ParamKind2) {
    return switch [k1, k2] {
      case [PKBody(None), PKBody(None)]: true;
      case [PKQuery(n1), PKQuery(n2)]
      | [PKHeader(n1), PKHeader(n2)]
      | [PKBody(Some(n1)), PKBody(Some(n2))]: n1 == n2;
      case _: false;
    }
  }
  
  public function byName(name:String):Array<ParamMapping> {
    return params.filter(function(p) return switch p.access {
      case Plain(n) | Drill(n, _): n == name;
    });
  }
  
  public function get(access:ArgAccess):Option<ParamMapping> {
    for(p in params)
      switch [access, p.access] {
        case [Plain(n1), Plain(n2)] if(n1 == n2): return Some(p);
        case [Drill(n1, f1), Drill(n2, f2)] if(n1 == n2 && f1 == f2): return Some(p);
        case _:
      }
    return None;
  }
  
  static function reserved(name:String) {
    return switch name {
      case 'user' | 'query' | 'header' | 'body': true;
      case _: false;
    }
  }
}

typedef RouteArg = {
  var name(default, null):String;
  var type(default, null):Type;
  var optional(default, null):Bool;
  var kind(default, null):RouteArgKind;
}

typedef RouteArg2 = {
  var name(default, null):String;
  var type(default, null):Type;
  var optional(default, null):Bool;
  var kind(default, null):ArgKind;
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

typedef ParamMapping = {
  source:Expr, // original expr specified in `@:params`
  access:ArgAccess,
  kind:ParamKind2,
}

enum ParamTarget {
  PTQuery(name:String);
  PTHeader(name:String);
  PTBody(name:Option<String>); // None means the entire body
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
  ATParam(kind:ParamKind2);
}

enum ParamKind2 {
  PKQuery(name:String);
  PKHeader(name:String);
  PKBody(name:Option<String>); // None denotes the entire body
}