package tink.web.macros;

#if macro
import tink.web.macros.Arguments;
import tink.web.macros.Parameters;

class Route {

  public var field(default, null):ClassField;
  public var kind(default, null):RouteKind;
  public var signature(default, null):Signature;
  public var consumes(default, null):Array<MimeType>;
  public var produces(default, null):Array<MimeType>;
  public var restricts(default, null):Array<Expr>;
  public var payload(get, null):Payload;

  static var id:Int = 0; // use global id counter to dodge https://github.com/haxetink/tink_macro/issues/25, but renders BuildCache useless

  public function new(f, consumes, produces, type) {
    field = f;
    signature = new Signature(f, type);
    switch [hasCall(f), hasSub(f)] {
      case [false, false]:
        f.pos.error('No routes on this field'); // should not happen actually
      case [true, false]:
        kind = KCall({
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
      case [false, true]:
        kind = KSub;
      case [true, true]:
        f.pos.error('Cannot have both routing and subrouting on the same field');
    }
    this.consumes = MimeType.fromMeta(f.meta, 'consumes', consumes);
    this.produces = MimeType.fromMeta(f.meta, 'produces', produces);

    restricts = getRestricts([field.meta]);
  }


  function get_payload():Payload {
    if(payload == null) {
      var arr = [];
      // var id = 0; // see https://github.com/haxetink/tink_macro/issues/25
      for(arg in signature.args) {
        switch arg.kind {
          case AKSingle(optional, ATParam(kind)):
            arr.push({id: id++, access: Plain(arg.name), type: arg.type, optional: optional, kind: kind});
          case AKObject(optional, fields):
            for(field in fields)
              switch field.target {
                case ATParam(kind):
                  arr.push({id: id++, access: Drill(arg.name, field.name), type: field.type, optional: optional || field.optional, kind: kind});
                case _: // skip
              }
          case _: // skip
        }
      }
      payload = new Payload(field.pos, arr);
    }
    return payload;
  }

  public static function hasWebMeta(f:ClassField) {
    return hasSub(f) || hasCall(f);
  }

  public static function hasCall(f:ClassField) {
    for (m in Paths.metas.keys())
       if (f.meta.has(m)) return true;
    return false;
  }

  public static function hasSub(f:ClassField) {
    return f.meta.has(':sub');
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
  KSub;
  KCall(call:Call);
}

typedef Call = {
  statusCode:Expr,
  headers:Array<NamedWith<Expr, Expr>>,
  html:Option<Expr>,
}

enum RoutePayload {
  Empty;
  Mixed(separate:Array<Field>, compound:Array<Named<Type>>, sum:ComplexType);
  SingleCompound(name:String, type:Type);
}


abstract Payload(Pair<Position, Array<{id:Int, access:ArgAccess, type:Type, optional:Bool, kind:ParamKind}>>) {
  public inline function new(pos, arr) this = new Pair(pos, arr);

  public function toTypes() {
    var flat = null;
    var body:Array<Field> = [];
    var query:Array<Field> = [];
    var header:Array<Field> = [];

    var pos = this.a;
    var arr = this.b;

    for(item in arr) {
      function add(to:Array<Field>, name:String) {
        var meta = [
          {name: ':json', params: [macro $v{name}], pos: pos},
          {name: ':formField', params: [macro $v{name}], pos: pos},
        ];

        if(item.optional)
          meta.push({name: ':optional', params: [], pos: pos});

        to.push({
          name: '_${item.id}',
          access: [],
          meta: meta,
          kind: FVar(item.type.toComplex(), null),
          pos: pos,
        });
      }

      switch item.kind {
        case PKBody(None):
          if(body.length > 0) pos.error('Body appeared more than once');
          flat = new Pair(item.access, item.type);
        case PKBody(Some(name)):
          if(flat != null) pos.error('Body appeared more than once');
          add(body, name);
        case PKQuery(name):
          add(query, name);
        case PKHeader(name):
          add(header, name);
      }
    }

    return {
      body: flat != null ? Flat(flat.a, flat.b) : Object(TAnonymous(body)),
      query: TAnonymous(query),
      header: TAnonymous(header),
    }
  }

  public function toObjectDecls() {
    var body = []; var bodyObj = EObjectDecl(body);
    var query = []; var queryObj = EObjectDecl(query);
    var header = []; var headerObj = EObjectDecl(header);

    var pos = this.a;
    var arr = this.b;

    for(item in arr) {
      function add(to, expr) {
        EObjectDecl(to); // type inference
        to.push({field: '_${item.id}', expr: expr});
      }
      switch [item.access, item.kind] {
        case [_, PKBody(None)]:
        case [Plain(name), PKBody(Some(_))]:
          add(body, macro $i{name});
        case [Plain(name), PKQuery(_)]:
          add(query, macro $i{name});
        case [Plain(name), PKHeader(_)]:
          add(header, macro $i{name});
        case [Drill(name, field), PKBody(Some(_))]:
          add(body, macro $p{[name, field]});
        case [Drill(name, field), PKQuery(_)]:
          add(query, macro $p{[name, field]});
        case [Drill(name, field), PKHeader(_)]:
          add(header, macro $p{[name, field]});
      }
    }

    return {
      body: bodyObj,
      query: queryObj,
      header: headerObj,
    }
  }

  public inline function iterator() return this.b.iterator();
}

enum BodyType {
  Flat(access:ArgAccess, type:Type);
  Object(type:ComplexType);
}
#end