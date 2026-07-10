# Parameters

In a HTTP request, parameters usually appear in four places:

1. in the path section of the URL
1. in the query section of the URL
1. in the request body
1. in the http header

In a nutshell, the supported syntaxes are as follow:

```haxe
@:<http_method>('/path/$param')
@:params(<ident> in <query|header|body>)
@:params(<ident> = <query|header|body>)
@:params(<ident> = <query|header|body>["native"])
@:params(<ident.field> in <query|header|body>)
@:params(<ident.field> = <query|header|body>["native"]));
```

## Path Parameters

Path parameters are part of the URL path:

- `/users/haxetink/repos`  
  In the above url, the part `haxetink` is variable
- `/users/haxetink/repos/tink_web`  
  In the above url, the parts `haxetink` and `tink_web` are variables

In `tink_web`, path parameters can be captured by a dollar sign `$` in the path.
Also, the parameter will be automatically converted to the specified type (`Int`, `Float`, `Bool`, `String`)

For example:

```haxe
@:get('/users/$user/repos')
public function repos(user:Int) {
	// suppose the path being routed is: `/users/123/repos`
	trace(user); // traces 123
}

@:get('/users/$user/repos/$repo')
public function repos(user:Int, repo:String) {
	// suppose the path being routed is: `/users/123/repos/tink_web`
	trace(user); // traces 123
	trace(repo); // traces 'tink_web'
}
```

### Optional parameter

Path parameters can be made optional if a default value is provided:

```haxe
@:get('/users')
@:get('/users/$user')
public function repos(user = 'haxetink') {
	// suppose the path being routed is: `/users`
	trace(user); // traces 'haxetink'
}
```

## Query Parameters

Query parameters appears in the URL, delimited by the `?` question mark.

Here are two examples:

- `https://lib.haxe.org/search/?v=test`  
  Query parameter is `v=test`
- `https://github.com/issues?utf8=%E2%9C%93&q=is%3Aopen+is%3Aissue`  
  Query parameter is `utf8=%E2%9C%93&q=is%3Aopen+is%3Aissue`
  
`tink_web` parses the [query string](https://en.wikipedia.org/wiki/Query_string) into a readily used form,
and then pass it as a special `query` argument to the handling function.

```haxe
@:get
public function search(query:{v:String}) {
	// suppose the path being routed is: `/search/?v=test`
	trace(query.v); // traces "test"
}

@:get
public function issues(query:{utf8:String, q:String}) {
	// suppose the path being routed is: `/issues?utf8=%E2%9C%93&q=is%3Aopen+is%3Aissue`
	trace(query.utf8); // traces "✓"
	trace(query.q); // traces "is:open is:issue"
}
```

And the parser is capable of converting basic types

```haxe
@:get
public function types(query:{int:Int, bool:Bool, float:Float}) {
	// suppose the path being routed is: `/types?int=1&bool=true&float=2.3`
	trace(query.int); // traces 1
	trace(query.bool); // traces true
	trace(query.float); // traces 2.3
}
```

### Optional parameter

Query parameters can be made optional by marking a field as optional:

```haxe
@:get
public function types(query:{?int:Int}) {
	// suppose the path being routed is: `/types`
	trace(query.int); // traces null
}
```

Also see `tink_querystring`

## Header Parameters

Header parameters are passed via the special `header` argument. Field names are matched case-insensitively against incoming request headers.

```haxe
@:get
public function api(header:{ authorization:String, accept:String }) {
	trace(header.authorization);
}
```

Use `@:name` on a struct field when the Haxe field name differs from the HTTP header name:

```haxe
@:get
public function api(header:{ var accept:String; @:name('x-api-key') var apiKey:String; }) {
	return header;
}
```

## Body Parameters

> Sometimes referred as Post Parameters, but is not actually limited to a `POST` request

As the name suggests, body parameters live in the [request body](request-body.md). See also [`tink_http`](https://haxetink.github.io/tink_http/) for lower-level request handling.
`tink_web` parses the body in a similar way as query parameters.

```haxe
@:post('/users')
public function createUser(body:{name:String}) {
	// do some database work here
	return 'Created User: ${body.name}';
}
```

### Optional parameter

Body parameters can be made optional by marking a field as optional:

```haxe
@:post('/users')
public function createUser(body:{?name:String}) {
	// now `body.name` can be null
}
```

## `@:params` metadata

The `@:params` metadata offers explicit control over where each argument is read from. The supported forms are listed in the introduction above.

### Scalar binding

Bind a single argument from query, header, or body:

```haxe
@:params(token in query)
@:get public function paramsInQuery(?token:String)
	return {token: token};

@:params(token in header)
@:get public function paramsInHeader(token:String)
	return {token: token};

@:params(token in body)
@:post public function paramsInBody(token:String)
	return {token: token};
```

### Object binding

When the argument is an anonymous structure, `@:params(obj in loc)` expands to per-field bindings from that location:

```haxe
@:params(obj in query)
@:get public function paramsObjInQuery(obj:{i:Int, s:String})
	return obj;
```

`@:params(obj = loc)` binds the whole anonymous object from query, header, or body:

```haxe
@:params(obj = query)
@:get public function paramsEqQuery(obj:{foo:String, ?bar:Int})
	return obj;

@:params(obj = header)
@:get public function paramsEqHeader(obj:{ var foo:String; @:name('x-bar') var bar:String; })
	return obj;
```

### Field and native-name binding

Bind individual fields or map to native parameter names:

```haxe
@:params(rec.foo in query)
@:get public function paramsFieldInQuery(rec:{foo:String})
	return rec;

@:params(alias = query['q'])
@:get public function paramsNativeQuery(alias:String)
	return {alias: alias};

@:params(rec.baz = body['b'])
@:post public function paramsFieldNativeBody(rec:{foo:String, baz:String})
	return rec;
```

### Merging parameters from multiple locations

Different fields of the same object can be bound from different places:

```haxe
@:params(obj.foo = query['foo'])
@:params(obj.bar = header['X-Bar'])
@:params(obj.baz = body['baz'])
@:post public function paramsMerged(obj:{foo:String, bar:String, baz:String})
	return obj;
```

Reserved argument names: `user`, `query`, `header`, `body`.

## Content Type

By default, the router accepts these request body formats:

- `application/json`
- `application/x-www-form-urlencoded`
- `multipart/form-data` (when compiled with `-D tink_multipart`)

Responses default to `application/json`.

Use `@:consumes` and `@:produces` on a class or individual route to override MIME types:

```haxe
@:consumes('application/json')
@:produces('application/json', 'text/html')
class Api {
	@:post public function create(body:{name:String}) { ... }
}
```

To modify the default list instead of replacing it, use `++` and `--`:

```haxe
@:consumes('application/json', --'application/x-www-form-urlencoded')
@:produces(++'text/plain')
class Api { ... }
```

#### `application/json`

Also see [`tink_json`](https://haxetink.github.io/tink_json/).

#### `application/x-www-form-urlencoded`

Also see [`tink_querystring`](https://haxetink.github.io/tink_querystring/).

#### `multipart/form-data`

Requires compiling with `-D tink_multipart`. See [Request Body](request-body.md) for file uploads with `FormFile`.

## Advanced Data Types

Beyond basic scalars, `tink_web` can parse and coerce richer types in path, query, header, and body arguments.

### Arrays and nested objects

```haxe
@:consumes('application/json')
@:post public function array(body:Array<Int>)
	return body;

@:params(bar in query)
@:get public function complex(query:{ foo: Array<{ ?x: String, ?y: Int, z: Float }> })
	return query;
```

Complex query strings with nested arrays are supported, e.g. `?foo[0].z=0&foo[1].x=hey&foo[1].z=1`.

### `Either` types

```haxe
@:consumes('application/json')
@:post public function either(body:{ field: Either<String, String> })
	return 'ok';
```

### Enum abstracts

Enum abstracts with a `toStringly()` conversion work in path, query, and body:

```haxe
@:enum abstract Status(String) {
	var Active = 'active';
	var Inactive = 'inactive';
	@:to public inline function toStringly():tink.Stringly return this;
}

@:get('/status/$v')
public function statusInPath(v:Status):Status
	return v;

@:params(v in query)
@:get public function statusInQuery(v:Status):Status
	return v;
```

### Dates

Date values are parsed when the target field type is `Date` (via `tink` string conversion).

### Raw and streaming bodies

For `String`, `Bytes`, or `RealSource` body arguments, see [Request Body](request-body.md).
