# Streaming (Server-Sent Events)

`tink_web` supports [Server-Sent Events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events) (SSE) for pushing a stream of typed events to the client over HTTP.

## Server

Return a `RealStream<T>` from a route handler. The router sets `Content-Type: text/event-stream` automatically:

```haxe
import tink.streams.Stream;

@:params(of in query)
@:get public function letters(of:String):tink.streams.RealStream<{ letter: String }>
	return Stream.ofIterator(
		of.split('').map(letter -> { letter: letter }).iterator()
	);
```

Each yielded value is serialized as a JSON SSE event. The stream is closed when the handler's `RealStream` completes.

## Client

When using a `Remote<T>` client, routes that return `RealStream<T>` on the server are exposed as `RealStream<T>` on the client as well. The macro handles SSE parsing via `tink.http.Sse`.

```haxe
import tink.Web;

var api = tink.Web.connect(('http://localhost:8080/':Api));

api.letters({ of: 'abc' }).each(function(event) {
	trace(event.letter);
});
```

You can also construct a `Remote` manually — see [Remoting](remoting.md).

## Related types

- `tink.streams.RealStream<T>` — async stream of events
- `tink.streams.Stream` — helpers to construct streams
- `tink.http.Sse` — low-level SSE parsing in `tink_http`

For non-SSE streaming responses (raw `RealSource` / `Bytes`), return those types directly from a route. See [Response](../basics/response.md).
