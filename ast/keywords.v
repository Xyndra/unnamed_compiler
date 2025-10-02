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
	let
	const
	inline
	// let x'. = ...
	// const x'. = ...
	// inline const x = ...
	// inline is not for functions. use macros for that.
	if
	else
	// if (...) { ... } else { ... }
	// if ...() { ..., ... -> {...} ..., ... -> {...} } else { ... }
	scope
	go
	// scope ... { ... }
	// go ...
	// go to a scope. this can go to a scope it is inside of or a scope defined before it.
	pinboard
	// pinboard '...
	// creates a "pinboard", which
	concept
}
