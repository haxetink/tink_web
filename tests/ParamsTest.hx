package;

import haxe.PosInfos;
import tink.core.Error.ErrorCode;
import tink.http.Header.HeaderField;
import tink.http.Response.OutgoingResponse;
import tink.web.routing.Context;
import tink.web.routing.Router;
import tink.web.proxy.Remote;
import tink.http.clients.LocalContainerClient;
import tink.http.containers.LocalContainer;
import tink.url.Host;
import tink.unit.Assert.*;
import deepequal.DeepEqual.*;

using tink.io.Source;
using tink.CoreApi;

@:asserts
@:allow(tink.unit)
class ParamsTest {

  static var routes = new ParamsRoutes();

  public static function exec(req:IncomingRequest):Promise<OutgoingResponse>
    return new Router<ParamsRoutes>(routes)
      .route(Context.ofRequest(req));

  var container:LocalContainer;
  var client:tink.http.Client;
  var proxy:Remote<ParamsRoutes>;

  public function new() {
    container = new LocalContainer();
    client = new LocalContainerClient(container);
    container.run(function (req:IncomingRequest) {
      return exec(req).recover(OutgoingResponse.reportError);
    });
    proxy = new Remote<ParamsRoutes>(client, new RemoteEndpoint(new Host('localhost', 80)));
  }

  // --- dispatch success (@:variant table) ---

  @:variant({token: 'abc'}, Helpers.get('/paramsInQuery?token=abc'))
  @:variant({token: null}, Helpers.get('/paramsInQuery'))
  @:variant({token: 'hdr'}, Helpers.get('/paramsInHeader', [new HeaderField('token', 'hdr')]))
  @:variant({token: 'json'}, Helpers.req('/paramsInBody', POST, [new HeaderField('content-type', 'application/json')], '{"token":"json"}'))
  @:variant({token: 'form'}, Helpers.req('/paramsInBody', POST, [new HeaderField('content-type', 'application/x-www-form-urlencoded')], 'token=form'))

  @:variant({foo: 'a', bar: 2}, Helpers.get('/paramsEqQuery?foo=a&bar=2'))
  @:variant({foo: 'a', bar: 'b'}, Helpers.get('/paramsEqHeader', [new HeaderField('foo', 'a'), new HeaderField('x-bar', 'b')]))
  @:variant({foo: 'a', bar: 4}, Helpers.req('/paramsEqBody', POST, [new HeaderField('content-type', 'application/json')], '{"foo":"a","bar":4}'))
  @:variant({foo: 'a', bar: 4}, Helpers.req('/paramsEqBody', POST, [new HeaderField('content-type', 'application/x-www-form-urlencoded')], 'foo=a&bar=4'))

  @:variant({alias: 'q'}, Helpers.get('/paramsNativeQuery?q=q'))
  @:variant({alias: 'tok'}, Helpers.get('/paramsNativeHeader', [new HeaderField('x-token', 'tok')]))
  @:variant({alias: 'json'}, Helpers.req('/paramsNativeBody', POST, [new HeaderField('content-type', 'application/json')], '{"payload":"json"}'))
  @:variant({alias: 'form'}, Helpers.req('/paramsNativeBody', POST, [new HeaderField('content-type', 'application/x-www-form-urlencoded')], 'payload=form'))

  @:variant({foo: 'f'}, Helpers.get('/paramsFieldInQuery?foo=f'))
  @:variant({foo: 'f'}, Helpers.get('/paramsFieldInHeader', [new HeaderField('foo', 'f')]))
  @:variant({foo: 'f'}, Helpers.req('/paramsFieldInBody', POST, [new HeaderField('content-type', 'application/json')], '{"foo":"f"}'))
  @:variant({foo: 'f'}, Helpers.req('/paramsFieldInBody', POST, [new HeaderField('content-type', 'application/x-www-form-urlencoded')], 'foo=f'))

  @:variant({foo: 'q'}, Helpers.get('/paramsFieldNativeQuery?q=q'))
  @:variant({foo: 'f'}, Helpers.get('/paramsFieldNativeHeader', [new HeaderField('x-foo', 'f')]))
  @:variant({foo: 'a', baz: 'b'}, Helpers.req('/paramsFieldNativeBody', POST, [new HeaderField('content-type', 'application/json')], '{"foo":"a","b":"b"}'))
  @:variant({foo: 'a', baz: 'b'}, Helpers.req('/paramsFieldNativeBody', POST, [new HeaderField('content-type', 'application/x-www-form-urlencoded')], 'foo=a&b=b'))

  @:variant({value: null}, Helpers.get('/paramsOptional'))
  @:variant({value: 'x'}, Helpers.get('/paramsOptional?value=x'))
  @:variant({value: 'req'}, Helpers.get('/paramsRequired?value=req'))
  @:variant({bar: 42}, Helpers.get('/paramsTypeError?bar=42'))

  @:variant({foo: 'foo', bar: 'bar', baz: 'baz'},
    Helpers.req('/paramsMerged?foo=foo', POST, [new HeaderField('content-type', 'application/json'), new HeaderField('x-bar', 'bar')], '{"baz":"baz"}'))
  @:variant({foo: 'foo', bar: 'bar', baz: 'baz'},
    Helpers.req('/paramsMerged?foo=foo', POST, [new HeaderField('content-type', 'application/x-www-form-urlencoded'), new HeaderField('x-bar', 'bar')], 'baz=baz'))

  @:variant({foo: 'f'}, Helpers.get('/temp?foo=f'))
  @:variant({foo: 'f', baz: 'b', query: 'foo=f&baz=b'}, Helpers.get('/alias?foo=f&baz=b'))
  @:variant({foo: null}, Helpers.req('/nullableQuery2', POST))
  @:variant(1, Helpers.get('/enumAbstractIntInQuery?v=1'))
  @:variant({ foo: ([ { z: .0 }, { x: 'hey', z: .1 }, { y: 4, z: .2 }, { x: 'yo', y: 5, z: .3 } ]:Array<Dynamic>) },
    Helpers.get('/complex?foo[0].z=.0&foo[1].x=hey&foo[1].z=.1&foo[2].y=4&foo[2].z=.2&foo[3].x=yo&foo[3].y=5&foo[3].z=.3'))
  public function dispatch(value:Dynamic, req:IncomingRequest)
    return expect(value, req);

  // --- dispatch errors (named methods) ---

  public function enumAbstractStringInQueryDispatch()
    return exec(Helpers.get('/enumAbstractStringInQuery?v=a')).next(function (o) {
      return o.body.all().next(function (b)
        return assert(b.toString() == '"a"')
      );
    });

  public function paramsRequiredMissing()
    return shouldFail(UnprocessableEntity, Helpers.get('/paramsRequired'));

  public function paramsTypeErrorInvalid()
    return shouldFail(UnprocessableEntity, Helpers.get('/paramsTypeError?bar=not-a-number'));

  // --- proxy round-trips ---

  public function proxyParamsInQuery() {
    return proxy.paramsInQuery('abc').next(o -> assert(compare({token: 'abc'}, o)));
  }

  public function proxyParamsInHeader() {
    return proxy.paramsInHeader('hdr').next(o -> assert(compare({token: 'hdr'}, o)));
  }

  public function proxyParamsInBody() {
    return proxy.paramsInBody('val').next(o -> assert(compare({token: 'val'}, o)));
  }

  public function proxyParamsEqQuery() {
    return proxy.paramsEqQuery({foo: 'a', bar: 2}).next(o -> assert(compare({foo: 'a', bar: 2}, o)));
  }

  public function proxyParamsEqHeader() {
    return proxy.paramsEqHeader({foo: 'a', bar: 'b'}).next(o -> assert(compare({foo: 'a', bar: 'b'}, o)));
  }

  public function proxyParamsEqBody() {
    return proxy.paramsEqBody({foo: 'a', bar: 4}).next(o -> assert(compare({foo: 'a', bar: 4}, o)));
  }

  public function proxyParamsNativeQuery() {
    return proxy.paramsNativeQuery('q').next(o -> assert(compare({alias: 'q'}, o)));
  }

  public function proxyParamsNativeHeader() {
    return proxy.paramsNativeHeader('tok').next(o -> assert(compare({alias: 'tok'}, o)));
  }

  public function proxyParamsNativeBody() {
    return proxy.paramsNativeBody('pay').next(o -> assert(compare({alias: 'pay'}, o)));
  }

  public function proxyParamsFieldInQuery() {
    return proxy.paramsFieldInQuery({foo: 'f'}).next(o -> assert(compare({foo: 'f'}, o)));
  }

  public function proxyParamsFieldInHeader() {
    return proxy.paramsFieldInHeader({foo: 'f'}).next(o -> assert(compare({foo: 'f'}, o)));
  }

  public function proxyParamsFieldInBody() {
    return proxy.paramsFieldInBody({foo: 'f'}).next(o -> assert(compare({foo: 'f'}, o)));
  }

  public function proxyParamsFieldNativeQuery() {
    return proxy.paramsFieldNativeQuery({foo: 'q'}).next(o -> assert(compare({foo: 'q'}, o)));
  }

  public function proxyParamsFieldNativeHeader() {
    return proxy.paramsFieldNativeHeader({foo: 'f'}).next(o -> assert(compare({foo: 'f'}, o)));
  }

  public function proxyParamsFieldNativeBody() {
    return proxy.paramsFieldNativeBody({foo: 'a', baz: 'b'}).next(o -> assert(compare({foo: 'a', baz: 'b'}, o)));
  }

  public function proxyParamsOptional() {
    return proxy.paramsOptional().next(o -> assert(compare({value: null}, o)));
  }

  public function proxyParamsRequired() {
    return proxy.paramsRequired('req').next(o -> assert(compare({value: 'req'}, o)));
  }

  public function proxyParamsTypeError() {
    return proxy.paramsTypeError(42).next(o -> assert(compare({bar: 42}, o)));
  }

  public function proxyParamsMerged() {
    return proxy.paramsMerged({foo: 'foo', bar: 'bar', baz: 'baz'})
      .next(o -> assert(compare({foo: 'foo', bar: 'bar', baz: 'baz'}, o)));
  }

  public function proxyComplex() {
    var c:ParamsRoutes.Complex = { foo: [ { z: 3, x: '5', y: 6 } ] };
    return proxy.complex(c).map(o -> assert(compare(c, o.sure())));
  }

  public function proxyTemp() {
    return proxy.temp({foo: 'f'}).next(o -> assert(compare({foo: 'f'}, o)));
  }

  public function proxyLetters() {
    final message = 'ab';
    var pos = 0;
    return proxy.letters(message).forEach(o -> {
      asserts.assert(o.letter == message.charAt(pos++));
      return tink.streams.Stream.Handled.Resume;
    }).next(_ -> asserts.done());
  }

  public function proxyEnumAbstractStringInQuery() {
    proxy.enumAbstractStringInQuery(ParamsRoutes.EStr.A)
      .next(o -> { asserts.assert(o == ParamsRoutes.EStr.A); return Noise; })
      .handle(asserts.handle);
    return asserts;
  }

  public function proxyEnumAbstractIntInQuery() {
    proxy.enumAbstractIntInQuery(ParamsRoutes.EInt.A)
      .next(o -> { asserts.assert(o == ParamsRoutes.EInt.A); return Noise; })
      .handle(asserts.handle);
    return asserts;
  }

  public function proxyAlias() {
    proxy.alias('f', {baz: 'b'})
      .next(o -> {
        asserts.assert(o.foo == 'f');
        asserts.assert(o.baz == 'b');
        asserts.assert(o.query == 'foo=f&baz=b');
        return Noise;
      })
      .handle(asserts.handle);
    return asserts;
  }

  public function proxyNullableQuery2() {
    proxy.nullableQuery2()
      .next(o -> { asserts.assert(o.foo == null); return Noise; })
      .handle(asserts.handle);
    return asserts;
  }

  // --- helpers ---

  static function expect(value:Dynamic, req:IncomingRequest, ?pos:PosInfos) {
    return exec(req).next(function (o):Promise<Assertion>
      return if (o.header.statusCode != 200)
        new Assertion(false, 'Request to ${req.header.url} failed because ${o.header.reason} (${o.header.statusCode.toInt()})');
      else
        o.body.all().next(function (b)
          return if (Std.is(value, String))
            assert(compare(value, b.toString(), pos), null, pos)
          else
            assert(compare(value, haxe.Json.parse(b.toString()), pos), null, pos)
        )
    );
  }

  static function shouldFail(code:ErrorCode, req:IncomingRequest, ?pos:PosInfos) {
    return exec(req)
      .map(function(o) return switch o {
        case Success(_): new Assertion(false, 'Expected Failure but got Success', pos);
        case Failure(e): assert(e.code == code, null, pos);
      });
  }

}
