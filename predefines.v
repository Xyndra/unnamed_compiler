module main

fn setup_predefines() map[string]Predefine {
	mut predefines := map[string]Predefine{}

	// Add built-in console.writeln function (with full module path)
	predefines['compat.console.writeln'] = Predefine_Func{
		arg_types:    [.string]
		return_types: .void
		callback:     fn (args []Types) ?Types {
			// Type checking is done before callback is called
			runes := args[0] as []rune
			println(runes.string())
			return none
		}
	}

	// Add base function: eqi (equals integer)
	predefines['eqi'] = Predefine_Func{
		arg_types:    [.isize, .isize]
		return_types: .bool
		callback:     fn (args []Types) ?Types {
			a := args[0] as isize
			b := args[1] as isize
			return Types(a == b)
		}
	}

	// Add base function: adi (add integer)
	predefines['adi'] = Predefine_Func{
		arg_types:    [.isize, .isize]
		return_types: .isize
		callback:     fn (args []Types) ?Types {
			a := args[0] as isize
			b := args[1] as isize
			// Automatic overflow detection
			result := a + b
			return Types(result)
		}
	}

	predefines['not'] = Predefine_Func{
		arg_types:    [.bool]
		return_types: .bool
		callback:     fn (args []Types) ?Types {
			a := !(args[0] as bool)
			return Types(a)
		}
	}

	return predefines
}
