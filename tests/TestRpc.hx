package;

import tink.web.routing.Context;
import deepequal.DeepEqual.compare;

@:asserts
class TestRpc {
  public function new() {}
  @:variant('/?action=foo&bar=123', {path:"/",bar:123,action:"foo"})
  @:variant('/?action=bar&foo=1', {path:"/",foo:true,action:"bar"})
  @:variant('/baz?action=foo&bar=123', {path:"/baz",bar:123,action:"foo"})
  @:variant('/baz?action=bar&foo=1', {path:"/baz",foo:true,action:"bar"})
  @:variant('/baz/tink?action=foo&bar=123', {path:"/baz/tink",bar:123,action:"foo"})
  @:variant('/baz/tink?action=bar&foo=1', {path:"/baz/tink",foo:true,action:"bar"})
  
  @:variant('/?action=foo&page=1&bar=123', {path:"/",bar:123,action:"foo",page:1})
  @:variant('/?action=foo&page=2&bar=123', {path:"/",bar:123,action:"foo",page:2})
  @:variant('/?action=bar&page=1&foo=1', {path:"/",foo:true,action:"bar",page:1})
  @:variant('/?action=bar&page=2&foo=1', {path:"/",foo:true,action:"bar",page:2})
  @:variant('/baz?action=foo&page=1&bar=123', {path:"/baz",bar:123,action:"foo",page:1})
  @:variant('/baz?action=foo&page=2&bar=123', {path:"/baz",bar:123,action:"foo",page:2})
  @:variant('/baz?action=bar&page=1&foo=1', {path:"/baz",foo:true,action:"bar",page:1})
  @:variant('/baz?action=bar&page=2&foo=1', {path:"/baz",foo:true,action:"bar",page:2})
  @:variant('/baz/tink?action=foo&page=1&bar=123', {path:"/baz/tink",bar:123,action:"foo",page:1})
  @:variant('/baz/tink?action=foo&page=2&bar=123', {path:"/baz/tink",bar:123,action:"foo",page:2})
  @:variant('/baz/tink?action=bar&page=1&foo=1', {path:"/baz/tink",foo:true,action:"bar",page:1})
  @:variant('/baz/tink?action=bar&page=2&foo=1', {path:"/baz/tink",foo:true,action:"bar",page:2})
  public function rpc(url:String, result:Dynamic) {
    var r = new tink.web.routing.Router<Rpcesque>(new Rpcesque());
    return r.route(tink.web.routing.Context.ofRequest(get(url)))
      .next(function(res) return res.body.all())
      .next(function(chunk) {
        asserts.assert(compare(result, haxe.Json.parse(chunk)));
        return asserts.done();
      });
  }
}

class Rpcesque {
  public function new() {}
  
  @:get('/?action=foo&page=1') public function foo1(ctx:Context, query:{ bar:Int }) return {path: ctx.getPath().toString(), bar: query.bar, action: 'foo', page: 1}
  @:get('/?action=bar&page=1') public function bar1(ctx:Context, query:{ foo:Bool }) return {path: ctx.getPath().toString(), foo: query.foo, action: 'bar', page: 1}
  @:get('/?action=foo&page=2') public function foo2(ctx:Context, query:{ bar:Int }) return {path: ctx.getPath().toString(), bar: query.bar, action: 'foo', page: 2}
  @:get('/?action=bar&page=2') public function bar2(ctx:Context, query:{ foo:Bool }) return {path: ctx.getPath().toString(), foo: query.foo, action: 'bar', page: 2}
  @:get('/baz?action=foo&page=1') public function bazFoo1(ctx:Context, query:{ bar:Int }) return {path: ctx.getPath().toString(), bar: query.bar, action: 'foo', page: 1}
  @:get('/baz?action=bar&page=1') public function bazBar1(ctx:Context, query:{ foo:Bool }) return {path: ctx.getPath().toString(), foo: query.foo, action: 'bar', page: 1}
  @:get('/baz?action=foo&page=2') public function bazFoo2(ctx:Context, query:{ bar:Int }) return {path: ctx.getPath().toString(), bar: query.bar, action: 'foo', page: 2}
  @:get('/baz?action=bar&page=2') public function bazBar2(ctx:Context, query:{ foo:Bool }) return {path: ctx.getPath().toString(), foo: query.foo, action: 'bar', page: 2}
  @:get('/baz/tink?action=foo&page=1') public function bazTinkFoo1(ctx:Context, query:{ bar:Int }) return {path: ctx.getPath().toString(), bar: query.bar, action: 'foo', page: 1}
  @:get('/baz/tink?action=bar&page=1') public function bazTinkBar1(ctx:Context, query:{ foo:Bool }) return {path: ctx.getPath().toString(), foo: query.foo, action: 'bar', page: 1}
  @:get('/baz/tink?action=foo&page=2') public function bazTinkFoo2(ctx:Context, query:{ bar:Int }) return {path: ctx.getPath().toString(), bar: query.bar, action: 'foo', page: 2}
  @:get('/baz/tink?action=bar&page=2') public function bazTinkBar2(ctx:Context, query:{ foo:Bool }) return {path: ctx.getPath().toString(), foo: query.foo, action: 'bar', page: 2}
  
  @:get('/?action=foo') public function foo(ctx:Context, query:{ bar:Int }) return {path: ctx.getPath().toString(), bar: query.bar, action: 'foo'}
  @:get('/?action=bar') public function bar(ctx:Context, query:{ foo:Bool }) return {path: ctx.getPath().toString(), foo: query.foo, action: 'bar'}
  @:get('/baz?action=foo') public function bazFoo(ctx:Context, query:{ bar:Int }) return {path: ctx.getPath().toString(), bar: query.bar, action: 'foo'}
  @:get('/baz?action=bar') public function bazBar(ctx:Context, query:{ foo:Bool }) return {path: ctx.getPath().toString(), foo: query.foo, action: 'bar'}
  @:get('/baz/tink?action=foo') public function bazTinkFoo(ctx:Context, query:{ bar:Int }) return {path: ctx.getPath().toString(), bar: query.bar, action: 'foo'}
  @:get('/baz/tink?action=bar') public function bazTinkBar(ctx:Context, query:{ foo:Bool }) return {path: ctx.getPath().toString(), foo: query.foo, action: 'bar'}
}