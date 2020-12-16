package tink.web.proxy;

import haxe.io.Bytes;
import tink.url.*;
import tink.querystring.*;
import tink.http.*;
import tink.http.Header;
import tink.http.Request;
import tink.http.Response;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
using tink.MacroApi;
#end

using tink.io.Source;
using tink.CoreApi;

#if !macro
@:genericBuild(tink.web.macros.Proxify.remote())
#end
class Remote<T> { }

private typedef RemoteEndpointData = {
  >Sub,
  host:Host,
  scheme:Scheme,
  ?pathSuffix:String,
}

private abstract Scheme(String) to String {
  inline function new(s) this = s;
  @:from static function fromString(s:String)
    return new Scheme(switch s {
      case null: '';
      case v:
        switch v.indexOf(':') {
          case -1: v;
          case i: v.substr(0, i);
        }
    });
}

private typedef Sub = {
  ?headers: Headers,
  ?path: PathFragments,
  ?query: QueryParams
}

abstract RemoteEndpoint(RemoteEndpointData) from RemoteEndpointData {

  public var host(get, never):Host;
    inline function get_host()
      return this.host;

  public var pathSuffix(get, never):String;
    inline function get_pathSuffix()
      return this.pathSuffix == null ? '' : this.pathSuffix;

  public var headers(get, never):Iterable<HeaderField>;
    inline function get_headers()
      return switch this.headers {
        case null: NO_HEADERS;
        case v: v;
      }

  static var NO_HEADERS = [];

  public var path(get, never):Iterable<Portion>;
    inline function get_path()
      return switch this.path {
        case null: NO_PATH;
        case v: v;
      }

  static var NO_PATH = [];

  public var query(get, never):QueryParams;
    inline function get_query()
      return this.query;

  public function new(host, ?pathSuffix, ?scheme)
    this = {
      host: host,
      pathSuffix: pathSuffix,
      scheme: scheme,
    };

  static function concat<E>(a:Array<E>, b:Array<E>)
    return switch [a, b] {
      case [null, r] | [r, null]: r;
      default: a.concat(b);
    }

  public function sub(options:Sub):RemoteEndpoint
    return {
      host: this.host,
      scheme: this.scheme,
      pathSuffix: this.pathSuffix,
      headers: concat(this.headers, options.headers),
      query: concat(this.query, options.query),
      path: concat(this.path, options.path),
    }

  function uri()
    return '/' + (switch this.path {
      case null: '';
      case v: Path.normalize(v.join('/'));
    }) + pathSuffix + this.query;

  public function request<A>(client:Client, method, body, reader:ResponseReader<A>):Promise<A>
    return
      client.request(
        new OutgoingRequest(
          new OutgoingRequestHeader(method, '${this.scheme}://${this.host}' + uri(), this.headers),
          body
        )
      ).next(function (response) return reader.withHeader(response.header)(response.body));

  @:from public static inline function fromHost(host:Host):RemoteEndpoint
    return new RemoteEndpoint(host);

  @:from static public function ofUrl(u:Url) {
    trace(u);
    return new RemoteEndpoint(u.host, u.hash, u.scheme).sub({
      headers: switch u.auth {
        case null: null;
        case v: [new HeaderField(AUTHORIZATION, HeaderValue.basicAuth(v.user, v.password))];
      },
      path: u.path.parts(),
      query: [for (p in u.query) new NamedWith((p.name:Portion), p.value)],
    });
  }

  @:from static public macro function ofString(e:ExprOf<String>)
    return switch e.getString() {
      default:
        return macro @:pos(e.pos) tink.web.proxy.Remote.RemoteEndpoint.ofUrl($e);
      case Success(s):

        var url = tink.Url.parse(s, function (v) {
          e.pos.error(v);
        });

        function interp(s:String)
          return
            if (s == null) macro null;
            else haxe.macro.MacroStringTools.formatString(s, e.pos);//todo: try to adjust position

        var fields = new Array<ObjectField>(),
            ret = @:pos(e.pos) macro new tink.web.proxy.Remote.RemoteEndpoint(new tink.url.Host(${interp(url.host)}), ${interp(url.hash)}, ${interp(url.scheme)});

        function add(field, expr)
          fields.push({ field: field, expr: expr });

        switch url.auth {
          case null:
          case v:
            add('headers', macro @:pos(e.pos) [
              new tink.http.Header.HeaderField(
                AUTHORIZATION,
                tink.http.Header.HeaderValue.basicAuth(${interp(v.user)}, ${interp(v.password)})
              )
            ]);
        }

        switch url.path {
          case null:
          case v:
            add('path', [for (p in v.parts()) macro new tink.url.Portion(${interp(p.raw)})].toArray());
        }

        switch url.query {
          case null:
          case v:
            add('query', [for (p in v) macro new tink.core.Named.NamedWith(
              new tink.url.Portion(${interp((p.name:Portion).raw)}),
              new tink.url.Portion(${interp(p.value.raw)})
            )].toArray());
        }

        if (fields.length != null)
          ret = macro @:pos(e.pos) $ret.sub(${EObjectDecl(fields).at(e.pos)});

        return ret;
    }

}

abstract ResponseReader<A>(ResponseHeader->RealSource->Promise<A>) from ResponseHeader->RealSource->Promise<A> {

  public function withHeader(header)
    return this.bind(header, _);

  @:from static function ofStringReader<A>(read:String->Outcome<A, Error>):ResponseReader<A>
    return
      function (header:ResponseHeader, body:RealSource):Promise<A>
        return
          body.all().next(function (chunk:Chunk) return
            if (header.statusCode >= 400)
              Failure(Error.withData(header.statusCode, header.reason, chunk.toString()));
            else
              read(chunk.toString())
          );

  @:from static function ofSafeStringReader<A>(read:String->A):ResponseReader<A>
    return ofStringReader(function (s) return Success(read(s)));

}

private typedef Headers = Array<HeaderField>;
private typedef PathFragments = Array<Portion>;

@:forward
abstract QueryParams(Array<NamedWith<Portion, Portion>>) to Array<NamedWith<Portion, Portion>> from Array<NamedWith<Portion, Portion>> {

  public inline function new()
    this = [];

  public inline function add(name:Stringly, value:Stringly):QueryParams {
    this.push(new NamedWith((name:Portion), (value:Portion)));
    return this;
  }

  @:to public inline function flush():QueryParams
    return this;

  @:to public function toString()
    return switch this {
      case null | []: '';
      default:
        var ret = Query.build();
        for (p in this)
          ret.add(p.name, p.value);
        '?$ret';
    }
}

@:forward
abstract HeaderParams(Headers) to Headers from Headers {

  public inline function new()
    this = [];

  public inline function add(name:HeaderName, value:HeaderValue):HeaderParams {
    this.push(new HeaderField(name, value));
    return this;
  }

  @:to public inline function flush():HeaderParams
    return this;

  @:to public function toString()
    return new Header(this).toString();
}

class RemoteBase<T> {

  var client:tink.http.Client;
  var endpoint:RemoteEndpoint;

  public function new(client, endpoint) {
    this.client = client;
    this.endpoint = endpoint;
  }

}