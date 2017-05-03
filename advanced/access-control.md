# Access Control

## Context

A `Router` requires a `Context` to work. A `Context` stores various information related to the current request.
In the [Quick Start](getting-started/quick-start) section we have seen that `Context.ofRequest(req)` can be used to create a `Context` from an `IncomingRequest`.

In order to employ access control, we need to created a `Context` that include information about the authenicated user (if any) for the current request. This is achieved by using `Context.authed(request, getSession)`

## Session

A session is defined as:

```haxe
typedef Session<User> = {
  function getUser():Promise<Option<User>>;  
}
```

So essentially it is a method that gives us an `User`.

In a HTTP request, the information about the authenticated user is pretty much stored in the request header (which includes the URL).
So in `Context.authed(request, getSession)`, `getSession` has the signature `IncomingRequestHeader->Session<User>`

Here is a sample `Session` implementation:

```haxe
class User {
	public var id(default, null):Int;
	public var isAdmin(get, never):Bool;
	
	public function new(id)
		this.id = id;
		
	inline function get_isAdmin()
		return id == 1;
}

class Session {
	var header:IncomingRequestHeader;
	
	public function new(header)
		this.header = header;
		
	public function getUser():Promise<Option<User>> {
		return switch header.byName('authorization') {
			case Success(auth):
				var username, password; 
				// ... do some work to extract the credentials here
				
				db.findUser(username, password) // this is a psuedo database call
					.next(function(user) 
						return 
							if(user == null)
								None
							else
								Some(new User(user.id))
					);
			case Failure(e):
				e;
				// or keep on searching other places for credentials, e.g. access token in query parameters
		}
	}
}

```

With this particular `Session` implemention, we can simply use the [constructor](http://haxe.org/blog/codingtips-new/) as `getSession`:

```haxe
Context.authed(request, Session.new);
```


## Meta

After using a authed `Context`, we can start putting some restrictions to the routes.
The simpliest way is to use the `@:restrict` metadata.

```haxe
@:restrict(true)
@:get('/')
public function get()
	return 'Done'
```

The parameter of `@:restrict` should resolve to a `Promise<Bool>`.

Behavior of the metadata is as follow:

1. if `@:restrict` exists, the `Context` must contain a user (i.e. `getUser()` in the `Session` must return `Some` user), otherwise the router will return a response` with `401 Unauthorized`.
1. if the expression of `@:restrict` resolves to a `false`, the router will return a response` with `403 Forbidden`

**Notes:**

- Multiple `@:restrict` metadata on a single route is allowed.
- `@:restrict(true)` means "any logged-in user will do".
- To reference the `User` object of the `Session`, use the `user` identifier (e.g. `@:restrict(user.isAdmin)`)
- To reference members in the current class (the router), use the `this` keyword. (e.g. `@:restrict(user.id > this.id)`)

## Fine-grained Control

In some cases the `@:restrict` metadata is not sufficient, we can ask the router to inject the `User` into the route,
using a specially-named argument `user`.


```haxe
@:get
public function dashboard(user:User) {
	if(user.isAdmin) {
		// show admin dashboard
	} else {
		// show normal dashboard
	}
}
```

`user`'s type can either be `User`, or `Option<User>`:

- If it is `User`, the router will return `401 Unauthorized` if there is no user in the current context.
- If it is `Option<User>`, the router will inject the `None` value to the route, if there is no user in the current context.

