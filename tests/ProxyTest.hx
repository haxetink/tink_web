package;

import deepequal.DeepEqual.compare;
import tink.http.Request;
import tink.http.Response;
import tink.http.Client;
import tink.http.Container;
import tink.http.clients.*;
import tink.http.containers.*;
import tink.url.Host;
import tink.web.proxy.Remote;
import tink.unit.Assert.assert;
import haxe.io.Bytes;

using tink.CoreApi;

@:asserts
class ProxyTest {
	var container:LocalContainer;
	var client:Client;
	var fake:Fake;
	var proxy:Remote<Fake>;

	public function new() {
		container = new LocalContainer();
		client = new LocalContainerClient(container);
		fake = new Fake();
		container.run(function(req:IncomingRequest) {
			return DispatchTest.exec(req).recover(OutgoingResponse.reportError);
		});
		proxy = new Remote<Fake>(client, new RemoteEndpoint(new Host('localhost', 80)));
	}

	public function complex() {
		var c:Fake.Complex = {foo: [{z: 3, x: '5', y: 6}]};
		return proxy.complex(c).map(function(o) return assert(compare(c, o.sure())));
	}

	public function typed() {
		return proxy.typed().next(function(o) {
			asserts.assert(o.header.contentType().sure().fullType == 'application/json');
			asserts.assert(o.body.message == 'This is typed!');
			asserts.assert((o : {message:String}).message == 'This is typed!');
			return asserts.done();
		});
	}

	public function ripUserArg() {
		return proxy.anonOrNot().next(function(o) return assert(o.id > -2));
	}

	public function noise() {
		proxy.noise().handle(function(o) switch o {
			case Success(o):
				asserts.assert(o == Noise);
				asserts.done();
			case Failure(e):
				asserts.fail('Expected Success(Noise)');
		});
		return asserts;
	}

	public function noiseWithError() {
		proxy.noise(true).handle(function(o) switch o {
			case Success(o):
				asserts.fail('Expected Failure(error); got: Success($o)');
			case Failure(e):
				asserts.assert(e.code == 500);
				asserts.done();
		});
		return asserts;
	}

	public function enumAbstractStringInQuery() {
		proxy.enumAbstractStringInQuery(Fake.EStr.A).next(function(o) {
			asserts.assert(o == Fake.EStr.A);
			return Noise;
		}).handle(asserts.handle);
		return asserts;
	}

	public function enumAbstractIntInQuery() {
		proxy.enumAbstractIntInQuery(Fake.EInt.A).next(function(o) {
			asserts.assert(o == Fake.EInt.A);
			return Noise;
		}).handle(asserts.handle);
		return asserts;
	}

	public function enumAbstractStringInPath() {
		proxy.enumAbstractStringInPath(Fake.EStr.A).next(function(o) {
			asserts.assert(o == Fake.EStr.A);
			return Noise;
		}).handle(asserts.handle);
		return asserts;
	}

	public function enumAbstractIntInPath() {
		proxy.enumAbstractIntInPath(Fake.EInt.A).next(function(o) {
			asserts.assert(o == Fake.EInt.A);
			return Noise;
		}).handle(asserts.handle);
		return asserts;
	}

	public function alias() {
		proxy.alias('f', {baz: 'b'}).next(function(o) {
			asserts.assert(o.foo == 'f');
			asserts.assert(o.baz == 'b');
			asserts.assert(o.query == 'foo=f&baz=b');
			return Noise;
		}).handle(asserts.handle);
		return asserts;
	}

	public function merged() {
		proxy.merged({foo: 'foo', bar: 'bar', baz: 'baz'}).next(function(o) {
			asserts.assert(o.foo == 'foo');
			asserts.assert(o.bar == 'bar');
			asserts.assert(o.baz == 'baz');
			return Noise;
		}).handle(asserts.handle);
		return asserts;
	}

	public function header() {
		proxy.headers({accept: 'application/json', bar: 'bar'}).next(function(o) {
			asserts.assert(o.accept == 'application/json');
			asserts.assert(o.bar == 'bar');
			return Noise;
		}).handle(asserts.handle);
		return asserts;
	}

	public function string() {
		proxy.textual('foo')
			.next(function(o) return o.body.all())
			.next(function(chunk) {
				asserts.assert(chunk.toString() == 'foo');
				return Noise;
			})
			.handle(asserts.handle);
		return asserts;
	}

	public function bytes() {
		proxy.buffered(Bytes.ofString('foo'))
			.next(function(o) return o.body.all())
			.next(function(chunk) {
				asserts.assert(chunk.toString() == 'foo');
				return Noise;
			})
			.handle(asserts.handle);
		return asserts;
	}

	public function source() {
		proxy.streaming('foo')
			.next(function(o) return o.body.all())
			.next(function(chunk) {
				asserts.assert(chunk.toString() == 'foo');
				return Noise;
			})
			.handle(asserts.handle);
		return asserts;
	}

	public function promiseString() {
		proxy.promiseString()
			.next(function(o) return o.body.all())
			.next(function(chunk) {
				asserts.assert(chunk.toString() == 'foo');
				return Noise;
			})
			.handle(asserts.handle);
		return asserts;
	}

	public function promiseBytes() {
		proxy.promiseBytes()
			.next(function(o) return o.body.all())
			.next(function(chunk) {
				asserts.assert(chunk.toString() == 'foo');
				return Noise;
			})
			.handle(asserts.handle);
		return asserts;
	}
}
