# Routing

## Introduction

`tink_web` utilizes metadata to build the routing scheme at _compile time_
(compared to _runtime_-built routing scheme as in some popular web frameworks such as Express.js)
Each metadata specifies both the HTTP verb and a path. There is also a special metadata
which allows sub-routing.

## HTTP Verbs

The following metadata are supported:

- `@:get`
- `@:post`
- `@:patch`
- `@:put`
- `@:delete`

and obviously they correspond to the common HTTP verbs: `GET`, `POST`, `PATCH`, `PUT`, `DELETE`.

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
	
	@:get
	public function male()
		return 'Martini';
		
	@:get
	public function female()
		return 'Sidecar';
}

class Foo {
	public function new() {}
	
	@:get
	public function lish()
		return 'foolish';
		
	@:get
	public function ter()
		return 'footer';
		
	@:get
	public function tball()
		return 'football';
		
}
```