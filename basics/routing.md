# Routing

`tink_web` utilizes metadata to build the routing scheme at _compile time_
(compared to _runtime_-built routing scheme as in some popular web frameworks such as Express.js).
Each metadata specifies both the HTTP verb and a path. There is also a special metadata
which allows sub-routing.

## HTTP Verbs

The following metadata are supported:

- `@:get`
- `@:post`
- `@:patch`
- `@:put`
- `@:delete`
- `@:head`
- `@:options`

and obviously they correspond to the common HTTP verbs: `GET`, `POST`, `PATCH`, `PUT`, `DELETE`, `HEAD` and `OPTIONS`.

If you would like a route to match no matter which method, you can use `@:all`.

### Path Specified

If the metadata comes with a string parameter, the function will then serve that specified path:

```haxe
// this serves a [GET /] request
@:get('/')
public function main()
	return 'foo';

// this serves a [POST /hello] request
@:post('/hello') 
public function hello()
	return 'Hello World!';
```

Also works on variables:

```haxe
// this serves a [PATCH /] request
@:patch('/') 
public var foo = 'foo';

// this serves a [PUT /welcome] request
@:put('/welcome') 
public var welcome = 'Welcome!';
```

### Path Unspecified

if the metadata does not have a parameter, the function/variable name will be used as the path name.

```haxe
// this serves a [DELETE /hello] request
@:delete
public function hello()
	return 'Hello World!';

// this serves a [GET /welcome] request
@:get
public var welcome = 'Welcome!';
```

## Sub-Routing

When build a complex API, it would be nice to organize related function with a cascaded
path stucture, like:

- `/bar/male`
- `/bar/female`
- `/foo/lish`
- `/foo/ter`
- `/foo/tball`

and then with the metadata `@:sub`, codes can be organized in a similar cascaded manner.

```haxe
class Root {
	public function new() {}
	
	// this route captures path begining with '/bar'
	// the returned instance will be used to route the remaining path parts
	@:sub
	public function bar()
		return new Bar();

	// this route captures path begining with '/foo'
	// the returned instance will be used to route the remaining path parts
	@:sub('/foo')
	public var whatever = new Foo();
}

class Bar {
	public function new() {}
	
	// [GET /bar/male] goes here
	@:get
	public function male()
		return 'Martini';
	
	// [GET /bar/female] goes here
	@:get
	public function female()
		return 'Sidecar';
}

class Foo {
	public function new() {}
	
	// [GET /foo/lish] goes here
	@:get
	public function lish()
		return 'foolish';
	
	// [GET /foo/ter] goes here
	@:get
	public function ter()
		return 'footer';
	
	// [GET /foo/tball] goes here
	@:get
	public function tball()
		return 'football';
		
}
```

### Sub-routing with path parameters

`@:sub` paths can include captured parameters:

```haxe
class Root {
	@:sub('/recurse/$id')
	public function recurse(id:String)
		return new Child(id);
}
```

## Advanced path patterns

### Mixed path interpolation

Path strings can mix literal text and captures. Each `$param` binds the next path segment:

```haxe
@:get('/colon/$foo:$bar')
public function colon(foo:Bool, bar:Float)
	return { foo: foo, bar: bar };
```

A request to `/colon/true:3.14` yields `foo = true` and `bar = 3.14`.

### Query-in-path capture

Query parameters can be captured directly in the route path:

```haxe
@:get('/queryParam?param=$value')
public function queryParam(value:String)
	return { value: value };
```

## Method mismatch (405)

When a request matches the path shape of a route but uses the wrong HTTP method, the router returns `405 Method Not Allowed` with an `Allow` header listing the permitted methods.

For example, if only `GET /onlyGet` is defined:

```haxe
@:get('/onlyGet') public function onlyGet()
	return 'ok';
```

A `POST /onlyGet` request receives `405` rather than `404`.

## Not found (404)

When no route matches the request path at all, the router returns `404 Not Found`.

