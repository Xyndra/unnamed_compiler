module ast

enum Keyword {
	module
	// module ...
	// basically namespaces in other languages, this is forced to be the first line of a file.
	import
	as
	// import ... as ...
	// never import without `as`
	fn
	return
	// fn ...(...,...) -> ... { ... return ... }
	// fn ...(...,...) -> code { ... return ... }
	// macros are like functions, but they are executed at compile time and return a string which becomes code
	var
	// var x'. = ...
	// '. means scope-pinned lifetime - variable is deleted when scope exits, like in normal languages
	// 'identifier will be supported for custom lifetimes in the future
	if
	else
	// if (...) { ... } else { ... }
	// if ...() { ..., ... -> {...} ..., ... -> {...} } else { ... }
	scope
	go
	// scope ... { ... }
	// go ...
	// go to a scope. this can go to a scope it is inside of or a scope defined before it.
	concept
	// concepts are a way to create DSLs using currying. TODO
}
