module ast

struct Parameter {
mut:
	name []rune
	type []rune
}

struct Function {
mut:
	name        []rune
	parameters  []Parameter
	return_type []rune
	body        Scope
}

fn handle_function(tokens []SecondTokenizerToken, token SecondTokenizerToken, mut i &int) !Function {
	mut func := handle_function_header(tokens, token, mut i)!
	func.body = handle_scope(tokens, token, mut i)!

	return func
}

fn handle_function_header(tokens []SecondTokenizerToken, token SecondTokenizerToken, mut i &int) !Function {
	mut func := Function{}
	i++
	// get function name
	if i >= tokens.len {
		return error('Expected function name after `fn` keyword, but reached end of file')
	}
	token2 := tokens[*i]
	if token2.type != .identifier {
		return error('Expected function name after `fn` keyword, but got `${token2.type}`')
	}
	func.name = token2.value or {
		return error('Expected function name after `fn` keyword, but got nothing')
	} as []rune
	i++
	// expect open parenthesis
	if i >= tokens.len {
		return error('Expected `(` after function name, but reached end of file')
	}
	token3 := tokens[*i]
	if token3.type != .open_parens {
		return error('Expected `(` after function name, but got `${token3.type}`')
	}
	// extract parameters
	for {
		i++
		if i >= tokens.len {
			return error('Expected parameter or `)` after `(`, but reached end of file')
		}
		token4 := tokens[*i]
		if token4.type == .close_parens {
			// end of parameters
			break
		}
		if token4.type != .identifier {
			return error('Expected parameter type, but got `${token4.type}`')
		}
		mut param := Parameter{}
		param.type = token4.value or { return error('Expected parameter tyoe, but got nothing') } as []rune
		i++
		if i >= tokens.len {
			return error('Expected parameter name after type, but reached end of file')
		}
		token6 := tokens[*i]
		if token6.type != .identifier {
			return error('Expected parameter name after type, but got `${token6.type}`')
		}
		param.name = token6.value or {
			return error('Expected parameter name after type, but got nothing')
		} as []rune
		func.parameters << param
		i++
		if i >= tokens.len {
			return error('Expected `,` or `)` after parameter, but reached end of file')
		}
		token7 := tokens[*i]
		if token7.type == .close_parens {
			// end of parameters
			break
		}
		if token7.type != .comma {
			return error('Expected `,` or `)` after parameter, but got `${token7.type}`')
		}
	}
	i++
	// check for return type
	if i >= tokens.len {
		return error('Expected return type or function body after parameters, but reached end of file')
	}
	token8 := tokens[*i]
	if token8.type != .identifier && token8.type != .open_brace {
		return error('Expected return type or function body after parameters, but got `${token8.type}`')
	}
	if token8.type == .identifier {
		func.return_type = token8.value or {
			return error('Expected return type or function body after parameters, but got nothing')
		} as []rune
		i++
		if i >= tokens.len {
			return error('Expected function body after return type, but reached end of file')
		}
	}
	// expect open brace
	token9 := tokens[*i]
	if token9.type != .open_brace {
		return error('Expected function body after return type, but got `${token9.type}`')
	}
	i++
	// expect newline
	if i >= tokens.len {
		return error('Expected newline after `{` in function body, but reached end of file')
	}
	token10 := tokens[*i]
	if token10.type != .newline {
		return error('Expected newline after `{` in function body, but got `${token10.type}`')
	}

	return func
}
