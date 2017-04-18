# Routing

## Session

Use `Context.authed()` to created a context with session:

```haxe
// TODO

```

## Authenticate

`Authorization` header

## Meta

```haxe
@:restrict
@:restrict(user.id > 1)
```



## Fine-grained Control

Use the special `user` argument:

```haxe
public function list(user) {
	
}
```
