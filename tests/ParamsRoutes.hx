package;

import tink.web.routing.Context;

typedef Complex = {
  foo: Array<{ ?x: String, ?y:Int, z:Float }>
}

class ParamsRoutes {

  public function new() {}

  // --- migrated from Fake.hx ---

  @:html(function (u) return '<html><body>Yo</body></html>')
  @:params(bar in query)
  @:get public function complex(query: Complex, ?bar:String)
    return query;

  @:params(bar.foo in query)
  @:get public function temp(bar:{foo:String})
    return bar;

  @:params(of in query)
  @:get public function letters(of:String):tink.streams.RealStream<{ letter: String }>
    return tink.streams.Stream.ofIterator(of.split('').map(letter -> { letter: letter }).iterator());

  @:params(v in query)
  @:get public function enumAbstractStringInQuery(v:EStr):EStr
    return v;

  @:params(v in query)
  @:get public function enumAbstractIntInQuery(v:EInt):EInt
    return v;

  @:params(notfoo = query['foo'])
  @:params(bar.baz = query['baz'])
  @:get public function alias(notfoo:String, bar:{baz:String}, ctx:Context):{foo:String, baz:String, query:String} {
    return {
      foo: notfoo,
      baz: bar.baz,
      query: @:privateAccess ctx.request.header.url.query,
    }
  }

  @:params(obj.foo = query['foo'])
  @:params(obj.bar = header['X-Bar'])
  @:params(obj.baz = body['baz'])
  @:post public function paramsMerged(obj:{foo:String, bar:String, baz:String}):{foo:String, bar:String, baz:String}
    return obj;

  @:params(nullableValue = query)
  @:post public function nullableQuery2(?nullableValue: { foo:String })
    return {foo: nullableValue == null ? null : nullableValue.foo};

  // --- ident in <loc> ---

  @:params(token in query)
  @:get public function paramsInQuery(?token:String)
    return {token: token};

  @:params(token in header)
  @:get public function paramsInHeader(token:String)
    return {token: token};

  @:params(token in body)
  @:post public function paramsInBody(token:String)
    return {token: token};

  // --- ident = <loc> ---

  @:params(obj = query)
  @:get public function paramsEqQuery(obj:{foo:String, ?bar:Int})
    return obj;

  @:params(obj = header)
  @:get public function paramsEqHeader(obj:{ var foo:String; @:name('x-bar') var bar:String; })
    return obj;

  @:params(obj = body)
  @:post public function paramsEqBody(obj:{foo:String, bar:Int})
    return obj;

  // --- ident = <loc>["native"] ---

  @:params(alias = query['q'])
  @:get public function paramsNativeQuery(alias:String)
    return {alias: alias};

  @:params(alias = header['X-Token'])
  @:get public function paramsNativeHeader(alias:String)
    return {alias: alias};

  @:params(alias = body['payload'])
  @:post public function paramsNativeBody(alias:String)
    return {alias: alias};

  // --- ident.field in <loc> ---

  @:params(rec.foo in query)
  @:get public function paramsFieldInQuery(rec:{foo:String})
    return rec;

  @:params(rec.foo in header)
  @:get public function paramsFieldInHeader(rec:{foo:String})
    return rec;

  @:params(rec.foo in body)
  @:post public function paramsFieldInBody(rec:{foo:String})
    return rec;

  // --- ident.field = <loc>["native"] ---

  @:params(rec.foo = query['q'])
  @:get public function paramsFieldNativeQuery(rec:{foo:String})
    return rec;

  @:params(rec.foo = header['X-Foo'])
  @:get public function paramsFieldNativeHeader(rec:{foo:String})
    return rec;

  @:params(rec.foo in body)
  @:params(rec.baz = body['b'])
  @:post public function paramsFieldNativeBody(rec:{foo:String, baz:String})
    return rec;

  // --- behavioral ---

  @:params(value in query)
  @:get public function paramsOptional(?value:String)
    return {value: value};

  @:params(value in query)
  @:get public function paramsRequired(value:String)
    return {value: value};

  @:params(bar in query)
  @:get public function paramsTypeError(bar:Int)
    return {bar: bar};

}

@:enum
abstract EStr(String) {
  var A = 'a';
  var B = 'b';

  @:to
  public inline function toStringly():tink.Stringly return this;
}

@:enum
abstract EInt(Int) {
  var A = 1;
  var B = 2;

  @:to
  public inline function toStringly():tink.Stringly return this;
}
