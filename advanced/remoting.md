# Remoting

`tink_web` provides a mechanism to access remote REST API in a type-safe way.

## Define remoting API

`tink_web` builds the remoting client at compile time. The API structure information can be provided as an `interface` or a `class` type.

> An interface is useful if the implementation is not written with `tink_web`, as demonstrated by the following example.
> However, even the server-side code is written with `tink_web`, while one can use the implemetation `class` file directly,
> it is still advisable to have a separate interface file which will be implemented by the server.
> So that the client-side code could rely on a clean interface file without server-side specifics which may otherwise be excluded by conditional compilation.

For example, we defined (partially) the API of [httpbin.org](http://httpbin.org/) with the following interface file.

``` haxe
interface Root {
	@:get('/get')
	@:params(name in query)
	function get(name:String):{args:Dynamic<String>};
	
	@:get('/json')
	function json():Result;
}

typedef Result = {
	slideshow:{
		title:String,
		author:String,
		date:String,
		slides:Array<{
			title:String,
			type:String,
			?items:Array<String>,
		}>,
	}
}
```

## Make an API call

In order to make an API request, we construct a `Remote` instance and call the instance methods on it.
A properly typed [`Promise`](https://haxetink.github.io/tink_core/#/types/promise) will be returned which can be handled by registering a callback through `.handle()`.

> `Remote` is a macro-built class that contains all the API functions. Each of the function has the appropriate encoding/decoding of the underlying HTTP request/response, which is again macro-built.

``` haxe
import tink.http.clients.*;
import tink.web.proxy.Remote;
import tink.url.Host;

class Client {
	static function main() {
		var remote = new Remote<Root>(new JsClient(), new RemoteEndpoint(new Host('httpbin.org', 80),"","http"));
		remote.get({name: 'Haxe'}).handle(function(o) switch o {
			case Success(result):
				trace($type(result));
				/*
				prints at compile-time (for the $type call):
					{args:Dynamic<String>}
				
				prints at run-time: 
					{
						"args": {
							"name": "Haxe"
						}
					}
				*/
				
			case Failure(e): trace(e);
		});
		
		remote.json().handle(function(o) switch o {
			case Success(result):
				trace($type(result));
				/*
				prints at compile-time (for the $type call):
					Result
					
				prints at run-time: 
					{
						"slideshow": {
							"title": "Sample Slide Show",
							"author": "Yours Truly",
							"date": "date of publication",
							"slides": [{
								"items": null,
								"title": "Wake up to WonderWidgets!",
								"type": "all"
							}, {
								"items": ["Why <em>WonderWidgets</em> are great", "Who <em>buys</em> WonderWidgets"],
								"title": "Overview",
								"type": "all"
							}]
						}
					}
				*/
				
			case Failure(e): trace(e);
		});
	}
}
```
