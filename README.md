# Tinkerbell Web Routing
[![Gitter](https://img.shields.io/gitter/room/nwjs/nw.js.svg?maxAge=2592000)](https://gitter.im/haxetink/public)

In simple terms, `tink_web` is a super-charged router for `tink_http`, that strives to embed the semantics of REST and HTTP into Haxe in a seamless way.

## Basic usage

Let's look at what a hello world app might look like:

```haxe
class Api {
  
  var greeting:String = 'hello';
  
  public function new() {}
  
  @:get('/$who')
  public function hello(who = 'world') 
    return '$greeting $who';
  
  @:post('/greeting')
  public function setGreeting(greeting):tink.Url {
    this.greeting = greeting;
    return '/';
  } 
}

var api = new Api();
var c:tink.http.Container = /* pick one */;
c.run(function (req) return tink.Web.route(req, api));
```

Note that POSTing new greetings will have no effect on non-permanent containers.