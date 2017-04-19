# Quick Start

## Install

### With Haxelib

`haxelib install tink_web`

### With Lix

`lix install haxelib:tink_web`

## Basic Router

```haxe
import tink.http.containers.*;
import tink.http.Response;
import tink.web.routing.*;

class Server {
	static function main() {
		var container = new NodeContainer(8080);
		var router = new Router<Root>(new Root());
		container.run(function(req) {
			return router.route(Context.ofRequest(req))
				.recover(OutgoingResponse.reportError);
		});
	}
}

class Root {
	public function new() {}
	
	@:get('/$name')
	public function hello(name = 'World')
		return 'Hello, $name!';
}
```

1. Copy the code above and save it as `Server.hx`
1. Build it with: `haxe -js server.js -lib hxnodejs -lib tink_web -main Server`
1. Run the server: `node server.js`
1. Now navigate to `http://localhost:8080` and you should see `Hello, World!`  
  and `http://localhost:8080/Tinkerbell` should print `Hello, Tinkerbell!`  
