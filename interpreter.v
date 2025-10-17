module main

import ast

type Types = Restruct
	| []rune
	| i8
	| i16
	| i32
	| i64
	| u8
	| u16
	| u32
	| u64
	| f32
	| f64
	| bool
	| isize

enum TypeKind {
	identifier
	string
	i8
	i16
	i32
	i64
	u8
	u16
	u32
	u64
	f32
	f64
	bool
	void
	isize
}

fn is_type_kind(t ?Types, kind TypeKind) bool {
	if t == none {
		return kind == .void
	}
	new_t := t or { return false }
	return match kind {
		.identifier { new_t is Restruct }
		.string { new_t is []rune }
		.i8 { new_t is i8 }
		.i16 { new_t is i16 }
		.i32 { new_t is i32 }
		.i64 { new_t is i64 }
		.u8 { new_t is u8 }
		.u16 { new_t is u16 }
		.u32 { new_t is u32 }
		.u64 { new_t is u64 }
		.f32 { new_t is f32 }
		.f64 { new_t is f64 }
		.bool { new_t is bool }
		.isize { new_t is isize }
		else { false }
	}
}

struct Identifier {
	name []rune
}

struct Predefine_Struct {
	contents map[string]TypeKind
}

struct Restruct {
mut:
	data []Types
}

fn (ps Predefine_Struct) from(args []Types) !Restruct {
	if args.len == 0 || args.len != ps.contents.len {
		return error('Not enough arguments to create struct, expected ${ps.contents.len}, got ${args.len}')
	}
	mut i := 0
	mut res := Restruct{}
	for _, kind in ps.contents {
		i++
		if !is_type_kind(args[i - 1], kind) {
			return error('Argument ${i} has wrong type, expected `${kind}`')
		}
		res.data << args[i - 1]
	}
	return res
}

struct Predefine_Func {
	arg_types    []TypeKind
	return_types TypeKind
	callback     fn (args []Types) ?Types @[required]
}

type Predefine = Predefine_Struct | Predefine_Func

struct Interpreter {
mut:
	predefines map[string]Predefine
	functions  map[string]ast.Function
	variables  map[string]Types
	aliases    map[string]string // alias -> full module path
}

fn new_interpreter() Interpreter {
	mut interp := Interpreter{}

	// Add built-in console.writeln function (with full module path)
	interp.predefines['compat.console.writeln'] = Predefine_Func{
		arg_types:    [.string]
		return_types: .void
		callback:     fn (args []Types) ?Types {
			if args.len != 1 {
				eprintln('console.writeln expects 1 argument, got ${args.len}')
				return none
			}
			if args[0] is []rune {
				runes := args[0] as []rune
				println(runes.string())
			}
			return none
		}
	}

	return interp
}

fn (mut interp Interpreter) load_file_ast(file_ast ast.FileAST) {
	// Register import aliases
	for imp in file_ast.imports {
		alias := imp.as.string()
		full_path := imp.mod.string()
		interp.aliases[alias] = full_path
	}

	// Register all functions
	for func in file_ast.functions {
		func_name := func.name.string()
		interp.functions[func_name] = func
	}
}

fn (mut interp Interpreter) run() ! {
	// Execute main function
	main_func := interp.functions['main'] or { return error('No main function found') }

	result := interp.execute_function(main_func, []Types{})!

	// Check return value
	if result is isize {
		exit_code := result as isize
		if exit_code != 0 {
			eprintln('Program exited with code: ${exit_code}')
			exit(int(exit_code))
		}
	}
}

fn (mut interp Interpreter) execute_function(func ast.Function, args []Types) !Types {
	// Save current variables state
	mut saved_vars := interp.variables.clone()

	// Set up parameters as variables
	if func.parameters.len != args.len {
		return error('Function ${func.name.string()} expects ${func.parameters.len} arguments, got ${args.len}')
	}

	for i, param in func.parameters {
		param_name := param.name.string()
		interp.variables[param_name] = args[i]
	}

	// Execute function body
	result := interp.execute_scope(func.body)!

	// Restore variables state
	interp.variables = saved_vars.move()

	return result
}

fn (mut interp Interpreter) execute_scope(scope ast.Scope) !Types {
	// Execute all statements
	for stmt in scope.statements {
		interp.execute_statement(stmt)!
	}

	// Handle return statement
	if ret := scope.return_statement {
		return interp.evaluate_value(ret.value)!
	}

	// No return value - return void/none as isize 0
	return Types(isize(0))
}

fn (mut interp Interpreter) execute_statement(stmt ast.Statement) ! {
	match stmt {
		ast.Value {
			// Execute value (typically a function call)
			interp.evaluate_value(stmt)!
		}
		ast.IfStatement {
			// TODO: Implement if statements
			return error('If statements not yet implemented')
		}
	}
}

fn (mut interp Interpreter) evaluate_value(val ast.Value) !Types {
	match val {
		ast.Number {
			// Parse number and return appropriate type
			text := val.text.string()
			// Try to parse as isize for return values
			num := text.parse_int(10, 64) or { return error('Failed to parse number: ${text}') }
			return Types(isize(num))
		}
		ast.String {
			// Return string as []rune
			return Types(val.text)
		}
		ast.Variable {
			// Look up variable
			var_name := val.name.string()
			return interp.variables[var_name] or { return error('Undefined variable: ${var_name}') }
		}
		ast.FunctionCall {
			return interp.execute_function_call(val)!
		}
	}
}

fn (mut interp Interpreter) execute_function_call(call ast.FunctionCall) !Types {
	func_name := call.name.string()

	// Resolve alias if present
	resolved_name := interp.resolve_alias(func_name)

	// Evaluate all arguments
	mut args := []Types{}
	for arg in call.arguments {
		args << interp.evaluate_value(arg)!
	}

	// Check if it's a predefined function
	if resolved_name in interp.predefines {
		predef := interp.predefines[resolved_name] or {
			return error('Function not found: ${resolved_name}')
		}
		if predef is Predefine_Func {
			result := predef.callback(args) or { return Types(isize(0)) }
			return result
		}
	}

	// Check if it's a user-defined function (use original name for user functions)
	if func_name in interp.functions {
		user_func := interp.functions[func_name]
		return interp.execute_function(user_func, args)!
	}

	return error('Unknown function: ${func_name}')
}

fn (interp Interpreter) resolve_alias(func_name string) string {
	// Check if the function name starts with an alias
	parts := func_name.split('.')
	if parts.len > 1 {
		first_part := parts[0]
		if first_part in interp.aliases {
			// Replace alias with full module path
			full_path := interp.aliases[first_part]
			rest := parts[1..].join('.')
			return '${full_path}.${rest}'
		}
	}
	return func_name
}

pub fn interpret(file_ast ast.FileAST) ! {
	mut interp := new_interpreter()
	interp.load_file_ast(file_ast)
	interp.run()!
}
