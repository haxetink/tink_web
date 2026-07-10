# Response

## Supported Return Types

The following types and their [`Future`](https://haxetink.github.io/tink_core/#/types/future)/[`Promise`](https://haxetink.github.io/tink_core/#/types/promise) variants are supported:

- `String`
- `Bytes`
- `RealSource` / `IdealSource` (see [`tink_io`](https://haxetink.github.io/tink_io/))
- `Chunk`
- `tink.web.routing.Response` / `OutgoingResponse` (see [`tink_http`](https://haxetink.github.io/tink_http/))
- `HttpStatusCode` (see [`http-status`](https://github.com/kevinresol/http-status))
- `Noise` — empty response body
- `tink.web.Response<T>` — typed response with explicit header and body
- `tink.Url` — redirect (use with `@:statusCode`)
- `RealStream<T>` — Server-Sent Events (see [Streaming](../advanced/streaming.md))
- Anything else is serialized to JSON or form-urlencoded based on `Accept` / `@:produces`

Inject `ctx: Context` as an argument to access the current request context from within a route handler.

## Meta

### `@:produces`

Declare response content types. The router picks the best match from the client's `Accept` header:

```haxe
@:produces('application/json', 'text/html')
@:get public function data()
	return { hello: 'world' };
```

### `@:html`

When the client accepts `text/html`, transform the return value with a rendering function:

```haxe
@:html(function(o) return '<p>Hello ${o.hello}</p>')
@:get public function hello()
	return { hello: 'world' };
```

### `@:statusCode`

Override the HTTP status code:

```haxe
@:statusCode(201)
@:post public function create()
	return 'Created';

@:statusCode(307)
@:get public function redirect()
	return tink.Url.parse('https://example.com');
```

### `@:header`

Add response headers. Multiple `@:header` metadata entries are allowed:

```haxe
@:header('X-Custom', 'value')
@:get public function withHeader()
	return 'ok';
```

## Empty responses

Return `Noise` or `Promise<Noise>` for a response with no body:

```haxe
@:get public function empty():Noise
	return Noise;

@:get public function emptyAsync():Promise<Noise>
	return Promise.NOISE;
```

## Typed responses

Return `tink.web.Response<T>` when you need full control over the response header and a typed body:

```haxe
@:get public function typed() {
	return new tink.web.Response(
		new tink.http.Response.ResponseHeader(200, 'OK', []),
		{message: 'This is typed!'}
	);
}
```

## Redirects

Return a `tink.Url` to redirect the client. Combine with `@:statusCode` for temporary (307) or permanent redirects:

```haxe
@:statusCode(307)
@:get('/old-path') public function moved()
	return tink.Url.parse('https://example.com/new-path');
```

## Streaming (SSE)

Returning `RealStream<T>` produces a `text/event-stream` response. See [Streaming](../advanced/streaming.md) for server and client usage.
