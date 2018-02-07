# Remoting
Remoting is tink's **(haxe?)** way to create a type-safe, easy to use client API requests, which is basically a really nice feature :)

## Define API interface
First, we need to define our API's interface, that can be a dedicated interface file or even the API implementation itself!

``` haxe
class Root {
	public function new() {}
	
	@:get('/')
	public function hello(query:{name:String}) {
		return {
			greetings: 'Hello, ${query.name}!',
		}
	}
}
```

## Make an API call
To make an API request, call to the functions that declared in the interface:

``` haxe
import tink.http.clients.*;
import tink.web.proxy.Remote;
import tink.url.Host;

class Client {
	static function main() {
		var remote = new Remote<Root>(new JsClient(), new RemoteEndpoint(new Host('localhost', 8080)));
		remote.hello({name: 'Haxe'}).handle(function(o) switch o {
			case Success(result): trace($type(result));
			case Failure(e): trace(e);
		});
	}
}
```
