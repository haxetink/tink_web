package tink.web.macros;

#if macro
import tink.web.macros.Arguments;

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
                for(field in fields) add(Drill(name, field.name), LOCATION_FACTORY[pos](getParamName(field)));
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

  static function conflictKind(k1:ParamKind, k2:ParamKind) {
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

  public static function getParamName(field:ClassField) {
    return switch field.meta.extract(':name') {
      case [{params: [macro $v{(name:String)}]}]: name;
      case [{params: _, pos: pos}]: pos.error('@:name meta should contain exactly one string literal parameter');
      case _: field.name;
    }
  }
}

typedef ParamMapping = {
  source:Expr, // original expr specified in `@:params`
  access:ArgAccess,
  kind:ParamKind,
}

enum ParamKind {
  PKQuery(name:String);
  PKHeader(name:String);
  PKBody(name:Option<String>); // None denotes the entire body
}
#end