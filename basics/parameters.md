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

## Body Parameters

> Sometimes referred as Post Parameters, but is not actually limited to a `POST` request

As the name suggests, body parameters lives in the [request body](#todo-link-to-tink-http).
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

### Content Type

!> This section is incomplete, contribute using the button at the bottom of the page

By default, parsers are generated for both `application/json` and `application/x-www-form-urlencoded`

Use metadata `@:consumes` to control that. It works on class and function level also:
```haxe
@:consumes('application/json')
public function createUser(body:{?name:String}) {
	// now `body.name` can be null
}
```

#### `application/json`
Also see `tink_json`
  
#### `application/x-www-form-urlencoded`
Also see `tink_querystring`

#### `multipart/form-data`

Requires `tink_multipart`

## Advanced Data Types

!> This section is incomplete, contribute using the button at the bottom of the page

- Array
- Object
- Date
- Enum
