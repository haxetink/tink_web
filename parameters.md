# Parameters

## Query Parameters

Use the special `query` argument.

```haxe
@:get('/users')
public function listUsers(query:{limit:Int}) {
	
}
```

Also see `tink_querystring`

## Body Parameters

Use the special `body` argument.

```haxe
@:post('/users')
public function createUser(body:{name:String}) {
	
}
```

### Content Type

By default, parsers are generated for both `application/json` and `application/x-www-form-urlencoded`

Use metadata `@:consume` to control that, blah.

#### `application/json`
Also see `tink_json`
  
#### `application/x-www-form-urlencoded`
Also see `tink_querystring`

#### `multipart/form-data`

Requires `tink_multipart`
