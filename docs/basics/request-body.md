# Request Body

This page covers raw and streaming request bodies, content negotiation, and file uploads. For structured field binding with `body:{...}` or `@:params`, see [Parameters](parameters.md).

## Structured body argument

The simplest form binds an anonymous structure from the request body (JSON or form-urlencoded by default):

```haxe
@:post
public function create(body:{name:String}) {
	return 'Created: ${body.name}';
}
```

## Raw body types

Routes can accept the body as a raw value instead of a parsed structure:

```haxe
@:post public function streaming(body:RealSource)
	return body;

@:post public function buffered(body:Bytes)
	return body;

@:post public function textual(body:String)
	return body;
```

`RealSource` is useful for proxying or transforming a request stream without buffering the entire body. `Bytes` and `String` read the full body into memory.

## Content negotiation

Use `@:consumes` to declare which request body formats a route accepts. This works at class or route level:

```haxe
@:consumes('application/json')
@:post public function jsonOnly(body:{name:String})
	return body.name;
```

When a client sends a body with a `Content-Type` the route does not accept, the router responds with `406 Not Acceptable`.

Default consumed formats are `application/json`, `application/x-www-form-urlencoded`, and (with `-D tink_multipart`) `multipart/form-data`. See [Parameters — Content Type](parameters.md#content-type) for `@:consumes`/`@:produces` modifiers (`++` / `--`).

## Multipart file uploads

File uploads require compiling with `-D tink_multipart` and adding the `tink_multipart` library.

Use `FormFile` from `tink.web.forms` for uploaded files:

```haxe
import tink.web.forms.FormFile;

@:post
public function upload(body:{ datafile: FormFile }) {
	return body.datafile.read().all().next(function(chunk) return {
		name: body.datafile.fileName,
		content: chunk.toString(),
	});
}
```

`Context.parse()` can also be used directly to obtain an `Array<Named<FormField>>` when lower-level access is needed.
