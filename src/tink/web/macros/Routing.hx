package tink.web.macros;

#if macro
import tink.macro.BuildCache;
import tink.web.macros.Paths;

class Routing {

  var routes:RouteCollection;
  var auth:Option<{ user: Type, session: Type }>;

  var cases:Array<Case> = [];
  var fields:Array<Field> = [];

  var depth:Int = 0;
  var named:Array<String> = [];
  var nameIndex:Map<String, Int> = new Map();
  var ctx:ComplexType;

  function new(routes, auth) {

    this.routes = routes;
    this.auth = auth;
    firstPass();
    ctx =
      switch auth {
        case Some(a):
          var user = a.user.toComplex(),
              session = a.session.toComplex();
          macro : tink.web.routing.Context.AuthedContext<$user, $session>;
        case None:
          macro : tink.web.routing.Context;
      }
  }

  function firstPass() {
    //during the first pass we skim all routes to map out their depths and named parameters
    for (route in routes) {

      function skim(paths:Iterable<Path>)
        for (path in paths) {

          switch path.parts.length {
            case sup if (sup > depth):
              depth = sup;
            default:
          }

          for (name in path.query.keys())
            if (!nameIndex.exists(name))
              nameIndex[name] = named.push(name) - 1;
        }

      switch route.kind {
        case KSub:
          skim(route.signature.paths);
        case KCall(c):
          skim(route.signature.paths);
      }

    }

  }

  function makeCase(field:String, funcArgs:Array<FunctionArg>, path:Path):Case {
    if (path.deviation.missing.length > 0)
      path.pos.error('Route does not capture all required variables. See warnings.');

    var pattern = [
      switch path.kind {
        case Call(Some(m)): macro $i{m};
        case _: IGNORE;
      },
    ];

    for (i in 0...depth * 2 + named.length * 2 + 1)
      pattern.push(IGNORE);

    for (i in 0...path.parts.length)
      pattern[i + 1 + depth] = macro true;

    if (path.rest == RNotAllowed)
      pattern[depth + 1 + path.parts.length] = macro false;

    var captured = new Map();

    function part(p)
      return switch p {
        case PConst(v):
          macro $v{v.toString()};
        case PCapture(Plain(name)):
          captured[name] = true;
          macro $i{name};
        case PCapture(Drill(name, field)):
          throw "TODO";
      }

    for (i in 0...path.parts.length)
      pattern[i + 1] = part(path.parts[i]);

    for (name in path.query.keys()) {

      var index = nameIndex[name];

      pattern[2 + index + depth * 2] = macro true;
      pattern[2 + index + depth * 2 + named.length] = part(path.query[name]);
    }

    var callArgs = [for (a in funcArgs)
      switch a.name {
        case '__depth__':
          macro $v{path.parts.length};
        case 'user' | 'session':
          macro $i{a.name};
        default:
          if (a == funcArgs[0] || captured[a.name])
            macro $i{a.name}
          else
            macro null;
      }
    ];

    return {
      values: [pattern.toArray(path.pos)],
      expr: macro @:pos(path.pos) this.$field($a{callArgs}),
    }
  }

  function switchTarget() {
    var ret = [macro ctx.header.method];

    for (i in 0...depth)
      ret.push(macro ctx.part($v { i } ));

    for (i in 0...depth+1)
      ret.push(macro l > $v{i});

    for (name in named)
      ret.push(macro ctx.hasParam($v{name}));

    for (name in named)
      ret.push(macro ctx.param($v{name}));

    return ret.toArray();
  }

  function restrict(restricts:Array<Expr>, e:Expr)
    return
      switch [restricts, auth] {
        case [[], _]:
          e;
        case [v, None]:
          v[0].pos.error('restriction cannot be applied because no session handling is provided');
        case [restricts, Some(_)]:

          for (v in restricts)
            e = macro @:pos(v.pos) (${substituteThis(v)} : tink.core.Promise<Bool>).next(
              function (authorized)
                return
                  if (authorized) $e;
                  else new tink.core.Error(Forbidden, 'forbidden')
            );

          macro ctx.user.get().next(function (o) return switch o {
            case Some(user):
              $e;
            case None:
              new tink.core.Error(Unauthorized, 'not authorized');
          });
      }

  function generate(name:String, pos:Position) {

    secondPass();


    var theSwitch = ESwitch(
      switchTarget(),
      cases,
      macro @:pos(pos) new tink.core.Error(NotFound, 'Not Found: [' + ctx.header.method + '] ' + ctx.header.url.pathWithQuery)
    ).at(pos);

    theSwitch = restrict(routes.restricts, theSwitch);

    var target = routes.type.toComplex();

    var ret =
      macro class $name {

        var target:$target;

        public function new(target) {
          this.target = target;
        }

        public function route(ctx:$ctx):tink.core.Promise<tink.http.Response.OutgoingResponse> {
          var l = ctx.pathLength;
          return $theSwitch;
        }
      };

    for (f in fields)
      ret.fields.push(f);

    ret.pack = ['tink', 'web'];

    return ret;
  }

  function routeMethod(route:Route) {
    var pos = route.field.pos,
        callArgs = [],
        funcArgs:Array<FunctionArg> = [{
          name: 'ctx',
          type: ctx,
        }];

    var field = route.field.name;

    var beforeBody = [function (e) return restrict(route.restricts, e)];

    for (arg in route.signature.args) {

      var argExpr = arg.name.resolve();

      switch arg.kind {
        case AKSingle(_, ATCapture):

          var expected = arg.type.toComplex();
          var enumAbstract = switch arg.type {
            case TAbstract(_.get() => {module: module, name: name, type: underlying, meta: meta, impl: impl}, _) if(meta.has(':enum')):
              var path = ('$module.$name').split('.');
              Some({
                underlying: underlying,
                fields: impl.get().statics.get()
                  .filter(function(s) return s.meta.has(':enum') && s.meta.has(':impl'))
                  .map(function(s) return macro $p{path.concat([s.name])})
              });
            case _:
              None;
          }

          var parsed = switch enumAbstract {
            case Some({fields: fields, underlying: underlying}):
              var underlyingCt = underlying.toComplex();
              var abstractCt = arg.type.toComplex();
              ESwitch(
                macro (cast (s:$underlyingCt):$abstractCt),
                [{expr: macro cast s, values: fields}],
                macro throw 'Invalid value "' + s + '" for field: ' + $v{arg.name}
              ).at(route.field.pos);
            case None:
              macro @:pos(route.field.pos) s;
          }

          argExpr = macro @:pos(route.field.pos) switch $argExpr.parse(function (s:tink.Stringly):$expected return $parsed) {
            case Success(v): v;
            case Failure(e): return tink.core.Promise.lift(e);
          }

          funcArgs.push({
            name: arg.name,
            type: macro : tink.Stringly,
            opt: arg.optional,
          });

        // case AKObject(fields):
        //   for(field in fields) {
        //     switch field.target {
        //       case ATParam(kind):
        //     }

        //   }
        // case AKSingle(ATParam(t, loc, PCompound):

            // if (!compound.exists(field.name))
            //   compound[loc] = [];

            // compound[loc].push(new Named(arg.name, t));

        // case AParam(t, loc, PSeparate):

        //   if (!separate.exists(loc))
        //     separate[loc] = [];

        //   separate[loc].push({
        //     name: arg.name,
        //     pos: route.field.pos,
        //     kind: FVar(t.toComplex()),
        //   });

        case AKSingle(_, ATUser(u)):

          beforeBody.push(function (e:Expr) {

            switch u.getID() {
              case 'haxe.ds.Option':
              default:
                e = macro @:pos(e.pos) switch user {
                  case Some(user): $e;
                  case None: new tink.core.Error(Unauthorized, 'unauthorized');
                }
            }

            return macro @:pos(e.pos) ctx.user.get().next(function (user) return $e);
          });
        case AKSingle(_, ATContext):
          var name = arg.name;
          beforeBody.push(function (e:Expr) return macro @:pos(e.pos) {
            var $name = ctx;
            $e;
          });
        default:

          // throw 'not implemented: '+arg.kind;
      }

      callArgs.push(
        if (arg.optional)
          macro switch $i{arg.name} {
            case null: null;
            default: $argExpr;
          }
        else argExpr
      );
    }

    var result = macro @:pos(pos) this.target.$field;

    if (route.field.type.reduce().match(TFun(_, _)))
      result = macro @:pos(pos) $result($a{callArgs});

    result =
      switch route.kind {
        case KSub:
          funcArgs.push({
            name: '__depth__',
            type: macro : Int,
          });

          var target = route.signature.result.asSubTarget().toComplex();

          var router = switch auth {
            case None:
              macro @:pos(pos) new tink.web.routing.Router<$target>(__target__);
            case Some(_.session.toComplex() => s):
              macro @:pos(pos) new tink.web.routing.Router<$s, $target>(__target__);
          }

          beforeBody.push(function (e) return macro {
            var ctx = ctx.sub(__depth__);
            $e;
          });

          macro @:pos(pos) {

            tink.core.Promise.lift($result)
              .next(function (__target__:$target)
                return $router.route(ctx)
              );
          }
        case KCall({statusCode: statusCode, headers: headers, html: html}):
          var headers = [for(h in headers) macro new tink.http.Header.HeaderField(${h.name}, ${h.value})];
          switch route.signature.result.asCallResponse() {
            case RNoise:
              macro @:pos(pos) tink.core.Promise.lift($result).next(
                function (_):tink.core.Promise<tink.web.routing.Response> {
                  return new tink.http.Response.OutgoingResponse(
                    new tink.http.Response.ResponseHeader(
                        $statusCode,
                        [new tink.http.Header.HeaderField(CONTENT_LENGTH, '0')].concat(${macro $a{headers}})
                    ),
                    Chunk.EMPTY
                  );
                }
              );
            case RData(t):
              var ct = t.toComplex();
              var formats = [];

              switch html {
                case Some(v):
                  formats.push(
                    macro @:pos(v.pos) if (ctx.accepts('text/html'))
                      return tink.core.Promise.lift(${substituteThis(v)}(__data__)).next(
                        function (d) return tink.web.routing.Response.textual('text/html', d)
                      )
                  );
                case None:
              }

              for (fmt in route.produces)
                formats.push(
                  macro @:pos(pos) if (ctx.accepts($v{fmt}))
                    return tink.web.routing.Response.textual(
                      $statusCode,
                      $v{fmt},
                      ${MimeType.writers.get([fmt], t, pos).generator}(__data__),
                      $a{headers}
                    )
                );

              macro @:pos(pos) tink.core.Promise.lift($result).next(
                function (__data__:$ct):tink.core.Promise<tink.web.routing.Response> {
                  $b{formats};
                  return new tink.core.Error(UnsupportedMediaType, 'Unsupported Media Type');
                }
              );

            case ROpaque(OParsed(res, t)):
              // @:statusCode and @:header is ignored here, we should probably error/warn
              var ct = res.toComplex();
              var formats = [];

              switch html {
                case Some(v):
                  formats.push(
                    macro @:pos(v.pos) if (ctx.accepts('text/html'))
                      return tink.core.Promise.lift(${substituteThis(v)}(__data__)).next(
                        function (d) return tink.web.routing.Response.textual('text/html', d)
                      )
                  );
                case None:
              }

              for (fmt in route.produces)
                formats.push(
                  macro @:pos(pos) if (ctx.accepts($v{fmt})) return ${{
                    macro new tink.http.Response.OutgoingResponse(
                      __data__.header.concat([new tink.http.Header.HeaderField(CONTENT_TYPE, $v{fmt})]),
                      ${MimeType.writers.get([fmt], t, pos).generator}(__data__.body)
                    );
                  }});

              macro @:pos(pos) tink.core.Promise.lift($result).next(
                function (__data__:$ct):tink.core.Promise<tink.web.routing.Response> {
                  $b{formats};
                  return new tink.core.Error(UnsupportedMediaType, 'Unsupported Media Type');
                }
              );

            case ROpaque(ORaw(t)):
              var ct = t.toComplex();
              function is(name:String) {
                var type = Context.getType(name);
                return t.unifiesWith(type) && type.unifiesWith(t);
              }

              var contentType =
                switch route.field.meta.extract(':produces') {
                  case []: macro null;
                  case [{ params: [v] }]: v;
                  case [m], _[1] => m:
                    m.pos.error('For opaque routes, @:produces must define exactly one constant content type');
                }

              var e =
                if (is('tink.io.Source.RealSource'))
                  macro @:pos(pos) tink.core.Promise.resolve(tink.web.routing.Response.ofRealSource($result, $contentType));
                else if(is('tink.io.Source.IdealSource'))
                  macro @:pos(pos) tink.core.Promise.resolve(tink.web.routing.Response.ofIdealSource($result, $contentType));
                else {
                  var ret =
                    if (is('tink.Chunk') && !contentType.expr.match(EConst(CIdent('null')))) macro tink.web.routing.Response.ofChunk(v, $contentType);
                    else macro (v : tink.web.routing.Response);

                  macro @:pos(pos) tink.core.Promise.lift($result)
                    .next(function (v:$ct) return $ret);
                }
              switch [statusCode, headers] {
                case [macro 200, []]:
                  e;
                case [macro 200, _]:
                  macro $e.next(function(res) return new tink.http.Response.OutgoingResponse(
                    res.header.concat(${macro $a{headers}}),
                    res.body
                  ));
                case [_, []]:
                  macro $e.next(function (res) return new tink.http.Response.OutgoingResponse(
                    new tink.http.Response.ResponseHeader($statusCode, $statusCode, @:privateAccess res.header.fields, res.header.protocol),
                    res.body
                  ));
                case _:
                  macro $e.next(function (res) return new tink.http.Response.OutgoingResponse(
                    new tink.http.Response.ResponseHeader($statusCode, $statusCode, @:privateAccess res.header.fields.concat(${macro $a{headers}}), res.header.protocol),
                    res.body
                  ));
              }
          }
      }

    var payload = route.payload;

    // map params into correct arg access
    var objects = new Map();
    var vars:Array<Var> = [];

    for(item in payload) {
      function plain(name:String, from:Expr) {
        var source = '_${item.id}';
        vars.push({name: name, type: null, expr: macro $from.$source});
      }
      function drill(name:String, field:String, from:Expr, root = false) {
        if(!objects.exists(name)) EObjectDecl(objects[name] = []);
        objects[name].push({
          field: field,
          expr: root ? from : {
            var source = '_${item.id}';
            macro $from.$source;
          }
        });
      }
      switch [item.access, item.kind] {
        case [Plain(name), PKBody(None)]:
          // TODO: not sure yet...
        case [Plain(name), PKBody(Some(_))]:
          plain(name, macro __body__);
        case [Plain(name), PKQuery(_)]:
          plain(name, macro __query__);
        case [Plain(name), PKHeader(_)]:
          plain(name, macro __header__);
        case [Drill(name, field), PKBody(None)]:
          drill(name, field, macro __body__, true);
        case [Drill(name, field), PKBody(Some(_))]:
          drill(name, field, macro __body__);
        case [Drill(name, field), PKQuery(_)]:
          drill(name, field, macro __query__);
        case [Drill(name, field), PKHeader(_)]:
          drill(name, field, macro __header__);
      }

      for(key in objects.keys()) {
        vars.push({
          name: key,
          type: route.signature.args.find(v -> v.name == key).type.toComplex(),
          expr: EObjectDecl(objects[key]).at(),
        });
      }

      result = macro {
        ${EVars(vars).at()}
        $result;
      }

    }


    // parse params
      var types = payload.toTypes();

      result = switch types.body {
        case Flat(Plain(name), t) if(is(t, 'haxe.io.Bytes')):
          macro @:pos(pos) ctx.allRaw().next(function ($name:tink.Chunk) return $result);

        case Flat(Plain(name), t) if(is(t, 'String')):
          macro @:pos(pos) ctx.allRaw().next(function ($name:tink.Chunk) {var $name = $i{name}.toString(); return $result;});

        case Flat(Plain(name), t) if(is(t, 'tink.io.Source')):
          macro @:pos(pos) {var $name = ctx.rawBody; $result;}

        case Flat(Plain(name), t):
          for(type in route.consumes)
            if(type != 'application/json')
              route.field.pos.error('Non-object body type only supports JSON encoding. Please add @:consumes("application/json") to this route and remove any other @:consumes metadata.');

          macro @:pos(pos) return ${bodyParser(t.toComplex(), route)}.next(function ($name) return $result);

        case Object(t = TAnonymous([])):
          result;

        case Object(t):
          macro @:pos(pos) return ${bodyParser(t, route)}.next(function (__body__) return $result);

        case kind:
          throw '$kind not implemented';
      }

      for (f in beforeBody)
        result = f(result);

      result = switch types.query {
        case TAnonymous([]):
          result;

        case t:
            macro @:pos(route.field.pos) tink.core.Promise.lift(new tink.querystring.Parser<$t>().tryParse(ctx.header.url.query))
              .next(function(__query__) return $result);
      }

      result = switch types.header {
        case TAnonymous([]):
          result;

        case t:
            macro @:pos(route.field.pos) tink.core.Promise.lift(new tink.querystring.Parser<tink.http.Header.HeaderValue->$t>().tryParse(ctx.headers()))
              .next(function(__header__) return $result);
      }

    // build and return the function

    var f:Function = {
      args: funcArgs,
      expr: macro @:pos(result.pos) return $result,
      ret: null,
    }

    fields.push({
      pos: pos,
      name: route.field.name,
      kind: FFun(f),
    });

    return funcArgs;
  }

  function secondPass()
    for (route in routes) {
      var args = routeMethod(route);
      for (path in route.signature.paths)
        cases.push(makeCase(route.field.name, args, path));
    }

  static var IGNORE = macro _;

  static function substituteThis(e:Expr)
    return switch e {
      case macro this.$field:
        macro @:pos(e.pos) (@:privateAccess this.target.$field);
      case macro this:
        macro @:pos(e.pos) (@:privateAccess this.target);
      default:
        e.map(substituteThis);
    }

  static function is(t:Type, name:String)
    return t.unifiesWith(Context.getType(name));

  static function bodyParser(payload:ComplexType, route:Route) {
    var cases:Array<Case> = [],
        structured = [],
        pos = route.field.pos;

    for (type in route.consumes)
      switch type {
        case 'application/x-www-form-urlencoded' #if tink_multipart | 'multipart/form-data' #end:
          structured.push(macro @:pos(pos) $v{type});
        default:
          cases.push({
            values: [macro $v{type}],
            expr: macro @:pos(pos) ctx.allRaw().next(
              function (b) return ${MimeType.readers.get([type], payload.toType(pos).sure(), pos).generator}(b.toString())
            )
          });
      }

    switch structured {
      case []:
      case v:
        cases.unshift({
          values: structured,
          expr: macro @:pos(pos) ctx.parse().next(function (pairs)
            return new tink.querystring.Parser<tink.web.forms.FormField->$payload>().tryParse(pairs)
          ),
        });
    }

    var contentType = macro @:pos(pos) switch ctx.header.contentType() {
      case Success(v): v.fullType;
      default: 'application/json';
    }

    cases.push({
      values: [macro invalid],
      expr: macro new tink.core.Error(NotAcceptable, 'Cannot process Content-Type '+invalid),
    });

    return macro @:pos(pos) (
      ${ESwitch(contentType, cases, null).at(pos)}
        :
      tink.core.Promise<$payload>
    );
  }

  static function build(ctx:BuildContextN) {

    var auth = None;

    var target = switch ctx.types {
      case []:
        switch Context.getCallArguments() {
          case null | []:
            ctx.pos.error('You must either specify a target type as type parameter or a target object as constructor argument');
          case [v]:
            v.typeof().sure();
          case _:
            ctx.pos.error('too many arguments - only one expected');
        }
      case [t]: t;
      case [s, t]:
        var sc = s.toComplex();

        var user =
          (macro @:pos(ctx.pos) {
            var x:$sc = null;
            function test<U>(s:tink.web.Session<U>):U {
              return null;
            }
            test(x);
          }).typeof().sure();

        auth = Some({ session: s, user: user });
        t;
      default:
        ctx.pos.error('Invalid usage');
    }

    var def = new Routing(
      new RouteCollection(
        target,
        [
          #if tink_multipart 'multipart/form-data', #end
          'application/x-www-form-urlencoded',
          'application/json'
        ],
        ['application/json']
      ),
      auth
    ).generate(ctx.name, ctx.pos);
    // trace(new haxe.macro.Printer().printTypeDefinition(def));
    return def;
  }

  static function apply() {
    return BuildCache.getTypeN('tink.web.routing.Router', build);
  }

}
#end