# Middleware

Middleware in `tink_web` is provided by [`tink_http`](https://haxetink.github.io/tink_http/#/addons/middleware). Middleware functions wrap an inner request handler, allowing cross-cutting concerns like logging, CORS, or authentication headers before the request reaches the router.

## Integration with `tink_web`

Compose middleware around the router's `route` call inside your container handler:

```haxe
import tink.http.containers.*;
import tink.web.routing.*;

var router = new Router<Root>(new Root());

container.run(function(req) {
	return logMiddleware(corsMiddleware(function(req) {
		return router.route(Context.ofRequest(req))
			.recover(OutgoingResponse.reportError);
	}))(req);
});
```

For authenticated routes, create an authed context inside the middleware chain:

```haxe
router.route(Context.authed(req, Session.new))
```

See the [tink_http middleware documentation](https://haxetink.github.io/tink_http/#/addons/middleware) for available middleware and how to write your own.
