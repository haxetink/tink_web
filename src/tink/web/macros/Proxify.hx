package tink.web.macros;

#if macro
import tink.macro.BuildCache;
import tink.http.Method;
import tink.url.Portion;
import tink.web.macros.Paths;

class Proxify {
  static function makeEndpoint(from:Path, route:Route, ?headers):Expr {
    if (headers == null)
      headers = [];

    var sig = route.signature;

    function capture(name:String):Expr {
      return macro @:pos(from.expr.pos) (($i{name} : tink.Stringly) : tink.url.Portion);
    }

    function val(p:PathPart)
      return switch p {
        case PCapture(Plain(name)): capture(name);
        case PCapture(Drill({name: name}, field)): throw 'TODO';
        case PMixed(fragments, captures): 
          final captures = [for (c in captures) capture(switch c {
            case Plain(name): name;
            default: throw 'TODO';
          })].toArray();
          macro this.__mergeFragments($v{fragments}, $captures);
        case PConst(s): macro $s;
      }

    var payload = route.payload;
    var types = payload.toTypes();
    var decls = payload.toObjectDecls();

    var path = from.parts.map(val);

    var ct = types.query;
    var query = [for (name in from.query.keys())
      macro new tink.CoreApi.NamedWith(${(name:Portion)}, ${val(from.query[name])})
    ].toArray();

    switch types.query {
      case TAnonymous([]): // skip
      case ct:
        query = macro $query.concat(
          new tink.querystring.Builder<$ct->tink.web.proxy.Remote.QueryParams>()
            .stringify(${decls.query.at()})
        );
    }

    var paramHeaders = switch types.header {
      case TAnonymous([]):
        macro [];
      case ct:
        macro new tink.querystring.Builder<$ct->tink.web.proxy.Remote.HeaderParams>()
          .stringify(${decls.header.at()});
    }

    return macro this.__tink_endpoint.sub({
      path: $a{path},
      query: $query,
      headers: [$a{headers}].concat($paramHeaders)
    });
  }

  static function build(ctx:BuildContext):TypeDefinition {
    var routes = new RouteCollection(ctx.type, ['application/json'], ['application/json']);
    return {
      pos: ctx.pos,
      pack: ['tink', 'web'],
      name: ctx.name,
      meta: [{name: ':pure', pos: ctx.pos}],
      fields: [for (f in routes) {
        pos: f.field.pos,
        name: f.field.name,
        meta: f.field.meta.get(),
        kind: FFun({
          args: [for (arg in f.signature.args) switch arg.kind {
            case AKSingle(_, ATUser(_) | ATContext): continue;
            case _: { name: arg.name, type: arg.type.toComplex(), opt: arg.optional };
          }],
          expr: {

            var call = [];

            switch f.kind {
              case KCall(c):

                var path = Variant.seek(f.signature.paths, f.field.pos);

                var method = switch path.kind {
                  case Call(Some(m)): m;
                  case _: GET;
                }

                var contentType = None;

                var payload = f.payload;

                var streaming = false;
                var body = switch payload.toTypes().body {
                  case Flat(Plain(name), type) if(Context.getType('tink.io.Source.RealSource').unifiesWith(type)):
                    streaming = true;
                    macro tink.io.Source.RealSourceTools.idealize($i{name}, function(_) return tink.io.Source.EMPTY);

                  case Flat(Plain(name), type) if(Context.getType('tink.io.Source.IdealSource').unifiesWith(type)):
                    streaming = true;
                    macro $i{name};

                  case Flat(Plain(name), type) if(Context.getType('haxe.io.Bytes').unifiesWith(type)):
                    macro $i{name};

                  case Flat(Plain(name), type) if(Context.getType('String').unifiesWith(type)):
                    macro $i{name};

                  case Flat(Plain(name), type):
                    var w = MimeType.writers.get(f.consumes, type, f.field.pos);
                    contentType = Some(w.type);
                    var writer = w.generator;
                    macro ${writer}($i{name});

                  case Flat(Drill({name: name}, field), type):
                    throw "TODO";

                  case Object(TAnonymous([])):
                    macro '';

                  case Object(_.toType().sure() => type):
                    var decl = payload.toObjectDecls().body;
                    var w = MimeType.writers.get(f.consumes, type, f.field.pos);
                    contentType = Some(w.type);
                    var writer = w.generator;
                    macro ${writer}(${decl.at()});
                }

                var response = f.signature.result.asCallResponse();

                var reader = switch response {
                  case RData(t) | ROpaque(OParsed(_, t)):
                    Some(MimeType.readers.get(f.produces, t, f.field.pos));
                  default: None;
                }

                var headers = {
                  var ret = [];

                  function add(name, value)
                    ret.push(macro new tink.http.Header.HeaderField($name, $value));

                  switch contentType {
                    case Some(v):
                      add(macro CONTENT_TYPE, macro $v{v});
                    default:
                  }

                  if (!streaming)
                    add(macro CONTENT_LENGTH, macro __body__.length);

                  switch reader {
                    case Some(v):
                      add(macro ACCEPT, macro $v{v.type});
                    default:
                  }

                  ret;
                }
                var endPoint = makeEndpoint(path, f, headers);
                var bodyCt = streaming ? macro:tink.io.Source.IdealSource : macro:tink.Chunk;

                final ret = macro @:pos(f.field.pos) {
                  var __body__:$bodyCt = $body;
                  return $endPoint.request(
                    this.__tink_client,
                    cast $v{method},
                    __body__,
                    ${switch response {
                      case RNoise:
                        // Explicit param/return types: Haxe 4.3+/5 do not bind request<A>
                        // from unannotated reader lambdas (A stays Unknown).
                        // Use full module-subtype paths (Haxe 5 resolves ComplexTypes strictly).
                        macro function(header:tink.http.Response.ResponseHeader, body:tink.io.Source.RealSource):tink.core.Promise<tink.core.Noise> {
                          return
                            if(header.statusCode >= 400)
                              tink.io.Source.RealSourceTools.all(body)
                                .next(function(chunk) return new tink.core.Error(header.statusCode, chunk))
                            else
                              tink.core.Promise.NOISE;
                        }
                      case RData(t):
                        reader.force().generator;

                      case ROpaque(OParsed(res, t)):
                        var ct = res.toComplex();
                        macro function(header:tink.http.Response.ResponseHeader, body:tink.io.Source.RealSource):tink.core.Promise<$ct>
                          return tink.io.Source.RealSourceTools.all(body)
                            .next(function(chunk) return ${reader.force().generator}(chunk))
                            .next(function(parsed):$ct return new tink.web.Response(header, parsed));

                      case ROpaque(ORaw(t)):
                        if (Context.getType('tink.http.Response.IncomingResponse').unifiesWith(t)) {
                          var ct = t.toComplex();
                          macro function(header:tink.http.Response.ResponseHeader, body:tink.io.Source.RealSource):tink.core.Promise<$ct>
                            return (new tink.http.Response.IncomingResponse(header, body):$ct);
                        }
                        else
                          macro function(header:tink.http.Response.ResponseHeader, body:tink.io.Source.RealSource):tink.core.Promise<tink.http.Response.IncomingResponse>
                            return new tink.http.Response.IncomingResponse(header, body);

                      case REvents(_.toComplex() => t):
                        macro function(header:tink.http.Response.ResponseHeader, body:tink.io.Source.RealSource)
                          return this.__parseSse(body, new tink.json.Parser<$t>().tryParse);
                    }}
                  );
                };

                if (response.match(REvents(_))) macro @:pos(ret.pos) return tink.streams.RealStream.promiseOfRealStream((() -> $ret)());// ew
                else ret;

              case KSub:

                var target = f.signature.result.asSubTarget().toComplex(),
                    path = Variant.seek(f.signature.paths, f.field.pos);

                macro @:pos(f.field.pos) return new tink.web.proxy.Remote<$target>(this.__tink_client, ${makeEndpoint(path, f)});
            }
          },
          ret: null,
        }),
        access: [APublic],
      }],
      kind: TDClass('tink.web.proxy.Remote.RemoteBase'.asTypePath([TPType(ctx.type.toComplex())])),
    }
  }

  static function remote():Type
    return BuildCache.getType('tink.web.proxy.Remote', build);

}
#end
