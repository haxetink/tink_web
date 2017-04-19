# Parameters

In HTTP, there are mainly two places to carry parameters, the query parameter and body parameters.

## Query Parameters

> Also known as Path Parameters

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

### Content Type

!> This section is incomplete, contribute using the button at the bottom of the page

By default, parsers are generated for both `application/json` and `application/x-www-form-urlencoded`

Use metadata `@:consume` to control that, blah.

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