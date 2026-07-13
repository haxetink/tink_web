package tink.web.macros;

#if macro
import haxe.macro.Type;
import tink.http.Method;
import tink.macro.BuildCache;
import tink.web.macros.Paths;
import tink.web.macros.Route;
import tink.web.macros.Arguments;

using haxe.macro.Tools;
using tink.MacroApi;
using tink.CoreApi;

class OpenApi {

  static final ALL_METHODS = [GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE];

  var paths:Array<{ path:String, operations:Array<Expr> }> = [];
  var schemas:Map<String, { ct:ComplexType, expr:Expr }> = new Map();
  var schemaCounter = 0;
  var anonCounter = 0;
  var visited:Map<String, Bool> = new Map();

  function new() {}

  static public function build(routes:RouteCollection, pos:Position):{ title:String, paths:Expr, schemas:Expr } {
    final gen = new OpenApi();
    gen.collect(routes, []);
    return gen.emit(routes.type, pos);
  }

  function typeKey(type:Type):String
    return type.toString();

  function typeTitle(type:Type):String {
    return switch type {
      case TInst(_.get() => c, _): c.name;
      case TAbstract(_.get() => a, _): a.name;
      case TType(_.get() => t, _): t.name;
      default: 'API';
    }
  }

  function collect(routes:RouteCollection, prefix:Array<PathPart>) {
    final key = typeKey(routes.type);
    if (visited.exists(key)) return;
    visited.set(key, true);

    for (route in routes)
      switch route.kind {
        case KSub:
          for (path in route.signature.paths)
            if (path.kind.match(Sub)) {
              final childType = route.signature.result.asSubTarget();
              final child = new RouteCollection(childType, route.consumes, route.produces);
              collect(child, prefix.concat(path.parts));
            }
        case KCall(call):
          for (path in route.signature.paths)
            switch path.kind {
              case Call(method):
                addCall(route, call, path, method, prefix);
              case Sub:
            }
      }
  }

  function addCall(route:Route, call:Call, path:Path, method:Option<Method>, prefix:Array<PathPart>) {
    final parts = prefix.concat(path.parts);
    final template = pathTemplate(parts);
    final methods = switch method {
      case Some(m): [m];
      case None: ALL_METHODS;
    }

    final parameters = pathParameters(parts, route)
      .concat(queryParameters(path, route))
      .concat(payloadParameters(route));

    final requestBody = buildRequestBody(route);
    final responses = buildResponses(route, call);

    final operations = [for (m in methods) {
      final methodName = (m:String).toLowerCase();
      final opId = route.field.name + (methods.length > 1 ? '_' + methodName : '');
      macro {
        method: $v{methodName},
        operationId: $v{opId},
        parameters: $a{parameters},
        requestBody: ${requestBody},
        responses: $a{responses},
      }
    }];

    paths.push({ path: template, operations: operations });
  }

  function pathTemplate(parts:Array<PathPart>):String {
    if (parts.length == 0) return '/';
    return '/' + [for (p in parts) switch p {
      case PConst(s): s.toString();
      case PCapture(Plain(name)): '{$name}';
      case PCapture(Drill({name: name}, field)): '{$name.$field}';
      case PMixed(_, captures):
        final name = switch captures[0] {
          case Plain(n): n;
          case Drill({name: n}, f): '$n.$f';
          case null: 'param';
        }
        '{$name}';
    }].join('/');
  }

  function argType(route:Route, name:String):Null<Type> {
    for (arg in route.signature.args)
      if (arg.name == name) return arg.type;
    return null;
  }

  function openApiType(type:Null<Type>):String {
    if (type == null) return 'string';
    return switch type.reduce() {
      case TAbstract(_.get() => {pack: [], name: 'Null'}, [t]): openApiType(t);
      case TAbstract(_.get() => {pack: [], name: 'Int'}, _)
         | TAbstract(_.get() => {pack: [], name: 'UInt'}, _): 'integer';
      case TAbstract(_.get() => {pack: [], name: 'Float'}, _): 'number';
      case TAbstract(_.get() => {pack: [], name: 'Bool'}, _): 'boolean';
      case TInst(_.get() => {pack: [], name: 'String'}, _): 'string';
      default: 'string';
    }
  }

  function captureName(access:ArgAccess):String
    return switch access {
      case Plain(name): name;
      case Drill({name: name}, field): '$name.$field';
    }

  function pathParameters(parts:Array<PathPart>, route:Route):Array<Expr> {
    final out = [];
    for (p in parts) switch p {
      case PCapture(access):
        final name = captureName(access);
        final type = switch access {
          case Plain(n): openApiType(argType(route, n));
          case Drill({name: n}, _): openApiType(argType(route, n));
        }
        out.push(macro {
          name: $v{name},
          place: 'path',
          required: true,
          type: $v{type},
        });
      case PMixed(_, captures):
        final name = captureName(captures[0]);
        out.push(macro {
          name: $v{name},
          place: 'path',
          required: true,
          type: 'string',
        });
      case PConst(_):
    }
    return out;
  }

  function queryParameters(path:Path, route:Route):Array<Expr> {
    return [for (name in path.query.keys()) {
      final part = path.query[name];
      final type = switch part {
        case PCapture(Plain(n)): openApiType(argType(route, n));
        case PCapture(Drill({name: n}, _)): openApiType(argType(route, n));
        default: 'string';
      }
      macro {
        name: $v{name},
        place: 'query',
        required: true,
        type: $v{type},
      }
    }];
  }

  function payloadParameters(route:Route):Array<Expr> {
    final out = [];
    for (item in route.payload) switch item.kind {
      case PKQuery(name):
        out.push(macro {
          name: $v{name},
          place: 'query',
          required: ${macro $v{!item.optional}},
          type: $v{openApiType(item.type)},
        });
      case PKHeader(name):
        out.push(macro {
          name: $v{name},
          place: 'header',
          required: ${macro $v{!item.optional}},
          type: $v{openApiType(item.type)},
        });
      case PKBody(_):
    }
    return out;
  }

  function isJson(mime:String):Bool
    return mime == 'application/json' || StringTools.endsWith(mime, '+json');

  function jsonTypes(mimes:Array<MimeType>):Array<String>
    return [for (m in mimes) if (isJson(m)) (m:String)];

  function canJsonSchema(type:Type):Bool {
    return switch type.reduce() {
      case TAbstract(_.get() => { module: 'tink.io.Source' }, _)
         | TInst(_.get() => { module: 'tink.io.Source' }, _)
         | TType(_.get() => { module: 'tink.io.Source' }, _):
        false;
      case TAbstract(_.get() => { module: 'tink.web.forms.FormFile' }, _)
         | TInst(_.get() => { module: 'tink.web.forms.FormFile' }, _)
         | TType(_.get() => { module: 'tink.web.forms.FormFile' }, _):
        false;
      case TInst(_.get() => { isInterface: true }, _):
        false;
      case TAnonymous(_.get() => { fields: fields }):
        for (f in fields)
          if (!canJsonSchema(f.type)) return false;
        true;
      default:
        true;
    }
  }

  function bodyType(route:Route):Null<Type> {
    return switch route.payload.toTypes().body {
      case Flat(_, type): type;
      case Object(TAnonymous([])): null;
      case Object(ct): ct.toType().sure();
    }
  }

  // Mirrors tink.json.macros.GenSchemaWriter.makeId so OpenAPI component ids
  // use real type names instead of tink.macro.DirectType_* proxies.
  function schemaIdFor(ct:ComplexType):String {
    final raw = switch ct {
      case TPath({pack: ['tink', 'macro'], name: 'DirectType'}):
        final t = ct.toType().sure();
        switch t {
          case TEnum(_, _) | TInst(_, _) | TAbstract(_, _): t.toString();
          default: 'Anon${anonCounter++}';
        }
      case TPath(_): ct.toString();
      default: 'Anon${anonCounter++}';
    };
    return ~/[^A-Za-z0-9_.]/g.replace(raw, '_');
  }

  function registerSchema(ct:ComplexType, pos:Position):String {
    final raw = schemaIdFor(ct);
    var key = raw;
    if (schemas.exists(key) && schemas.get(key).ct.toString() != ct.toString())
      key = 'Schema${schemaCounter++}_$raw';
    if (!schemas.exists(key))
      schemas.set(key, { ct: ct, expr: macro @:pos(pos) new tink.json.schema.SchemaWriter<$ct>().write() });
    return key;
  }

  function buildRequestBody(route:Route):Expr {
    final body = bodyType(route);
    if (body == null) return macro null;

    final json = jsonTypes(route.consumes);
    final contentTypes = json.length > 0 ? json : [(route.consumes[0]:String)];
    final schemaId =
      if (json.length > 0 && canJsonSchema(body))
        registerSchema(body.toComplex({ direct: true }), route.field.pos);
      else
        null;

    return macro {
      required: true,
      contentTypes: $v{contentTypes},
      schemaId: ${schemaId == null ? macro null : macro $v{schemaId}},
    }
  }

  function statusCodeString(expr:Expr):String {
    return switch expr.expr {
      case EConst(CInt(n)): Std.string(n);
      default: '200';
    }
  }

  function buildResponses(route:Route, call:Call):Array<Expr> {
    final status = statusCodeString(call.statusCode);
    final json = jsonTypes(route.produces);

    return switch route.signature.result.asCallResponse() {
      case RNoise:
        [macro {
          status: $v{status},
          contentTypes: null,
          schemaId: null,
        }];
      case REvents(_):
        [macro {
          status: $v{status},
          contentTypes: ['text/event-stream'],
          schemaId: null,
        }];
      case ROpaque(ORaw(_)):
        final types = route.produces.length > 0 ? [for (m in route.produces) (m:String)] : null;
        [macro {
          status: $v{status},
          contentTypes: ${types == null ? macro null : macro $v{types}},
          schemaId: null,
        }];
      case ROpaque(OParsed(_, data)):
        final schemaId = json.length > 0 && canJsonSchema(data)
          ? registerSchema(data.toComplex({ direct: true }), route.field.pos)
          : null;
        [macro {
          status: $v{status},
          contentTypes: $v{json.length > 0 ? json : [for (m in route.produces) (m:String)]},
          schemaId: ${schemaId == null ? macro null : macro $v{schemaId}},
        }];
      case RData(type):
        final schemaId = json.length > 0 && canJsonSchema(type)
          ? registerSchema(type.toComplex({ direct: true }), route.field.pos)
          : null;
        [macro {
          status: $v{status},
          contentTypes: $v{json.length > 0 ? json : [for (m in route.produces) (m:String)]},
          schemaId: ${schemaId == null ? macro null : macro $v{schemaId}},
        }];
    }
  }

  function emit(type:Type, pos:Position):{ title:String, paths:Expr, schemas:Expr } {
    final title = typeTitle(type);
    final pathExprs = [for (p in paths) macro @:pos(pos) {
      path: $v{p.path},
      operations: $a{p.operations},
    }];

    final schemaExprs = [for (id => s in schemas) macro @:pos(pos) {
      id: $v{id},
      schema: ${s.expr},
    }];

    return {
      title: title,
      paths: macro @:pos(pos) $a{pathExprs},
      schemas: macro @:pos(pos) $a{schemaExprs},
    };
  }

  static function buildDocument(ctx:BuildContextN) {
    final target = switch ctx.types {
      case [t]: t;
      default: ctx.pos.error('OpenApiDocument requires exactly one type parameter');
    }

    final routes = new RouteCollection(
      target,
      [
        #if tink_multipart 'multipart/form-data', #end
        'application/x-www-form-urlencoded',
        'application/json'
      ],
      ['application/json']
    );

    final emitted = build(routes, ctx.pos);
    final name = ctx.name;
    final defaultTitle = emitted.title;
    final pathsExpr = emitted.paths;
    final schemasExpr = emitted.schemas;

    return macro class $name {
      var doc:tink.web.spec.OpenApi.OpenApiDoc;

      public function new(?options:{
        ?info:tink.web.spec.OpenApi.OpenApiInfo,
        ?servers:Array<tink.web.spec.OpenApi.OpenApiServer>,
        ?tags:Array<tink.web.spec.OpenApi.OpenApiTag>,
        ?externalDocs:tink.web.spec.OpenApi.OpenApiExternalDocs,
      }) {
        final info:tink.web.spec.OpenApi.OpenApiInfo = if (options != null && options.info != null)
          options.info
        else
          { title: $v{defaultTitle}, version: '0.0.0' };

        this.doc = {
          info: info,
          paths: $pathsExpr,
          schemas: $schemasExpr,
          servers: options != null ? options.servers : null,
          tags: options != null ? options.tags : null,
          externalDocs: options != null ? options.externalDocs : null,
        };
      }

      public function json():String {
        return tink.web.spec.OpenApi.write(this.doc);
      }
    };
  }

  static function apply() {
    return BuildCache.getTypeN('tink.web.spec.OpenApiDocument', buildDocument);
  }
}
#end
