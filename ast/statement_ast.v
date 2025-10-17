module ast

pub type Value = Number | String | Variable | FunctionCall
pub type Statement = Value | IfStatement

pub struct Number {
pub:
	text []rune
}

pub struct String {
pub:
	text []rune
}

pub struct Variable {
pub:
	name []rune
}

pub struct FunctionCall {
pub mut:
	name      []rune
	arguments []Value
}

pub struct Return {
pub mut:
	value Value
}

pub struct IfStatement {
pub mut:
	condition Statement
	body      Scope
}

pub struct Scope {
pub mut:
	statements       []Statement
	return_statement ?Return
}

fn handle_scope(tokens []SecondTokenizerToken, token SecondTokenizerToken, mut i &int) !Scope {
	mut statements := []Statement{}
	for {
		i++
		if i >= tokens.len {
			return error('Expected scope body or `}` but reached end of file')
		}
		token2 := tokens[*i]
		match true {
			token2.type == .close_brace {
				// end of scope
				// expect newline
				i++
				if i < tokens.len {
					token3 := tokens[*i]
					if token3.type != .newline {
						return error('Expected newline after `}`, but got `${token3.type}`')
					}
				}
				break
			}
			token2.type == .newline {
				// ignore newlines in scope body
				continue
			}
			token2.type == .keyword {
				value := token2.value or { return error('Expected keyword, but got nothing') } as Keyword
				match value {
					.return {
						i++
						if i >= tokens.len {
							return error('Expected value after `return` keyword, but reached end of file')
						}
						token3 := tokens[*i]
						return_value := handle_value(tokens, token3, mut i)!
						// expect newline
						if i >= tokens.len {
							return error('Expected newline after return value, but reached end of file')
						}
						token4 := tokens[*i]
						if token4.type != .newline {
							return error('Expected newline after return value, but got `${token4.type}`')
						}
						// expect closing brace
						i++
						if i >= tokens.len {
							return error('Expected `}` after return statement, but reached end of file')
						}
						token5 := tokens[*i]
						if token5.type != .close_brace {
							return error('Expected `}` after return statement, but got `${token5.type}`')
						}

						return Scope{
							statements:       statements
							return_statement: Return{
								value: return_value
							}
						}
					}
					else {
						dump(token2)
					}
				}
			}
			token2.type == .identifier {
				statements << handle_single_statement(tokens, token2, mut i)!
			}
			else {
				return error('Unexpected token in scope body: `${token2.type}`')
			}
		}
	}
	return Scope{
		statements:       statements
		return_statement: none
	}
}

fn handle_single_statement(tokens []SecondTokenizerToken, token SecondTokenizerToken, mut i &int) !Statement {
	// function call or variable set
	mut full_identifier := []rune{}
	// get full identifier (with dots)
	for {
		token3 := tokens[*i]
		match token3.type {
			.identifier {
				full_identifier << (token3.value or {
					return error('Expected identifier, but got nothing')
				} as []rune)
				i++
				if i >= tokens.len {
					return error('Expected `=` or `(` after identifier, but reached end of file')
				}
			}
			.period {
				full_identifier << `.`
				i++
				if i >= tokens.len {
					return error('Expected identifier after `.`, but reached end of file')
				}
			}
			.open_parens {
				// start of arguments
				break
			}
			.equals {
				// variable set
				break
			}
			else {
				dump(token3)
				dump(full_identifier)
				return error('Expected identifier, `.`, `=` or `(`, but got `${token3.type}`')
			}
		}
	}
	// check if function call or variable set
	token4 := tokens[*i]
	i++
	if token4.type == .open_parens {
		// function call
		return Value(handle_function_call(tokens, full_identifier, mut i)!)
	} else if token4.type == .equals {
		// variable set
	}
	return error('Not implemented')
}

fn handle_value(tokens []SecondTokenizerToken, token SecondTokenizerToken, mut i &int) !Value {
	// skip newlines
	mut new_token := token
	for new_token.type == .newline {
		i++
		if i >= tokens.len {
			return error('Expected value, but reached end of file')
		}
		new_token = tokens[*i]
	}
	match new_token.type {
		.number {
			i++
			return Number{
				text: new_token.value or { return error('Expected number value, but got nothing') } as []rune
			}
		}
		.string {
			i++
			return String{
				text: new_token.value or { return error('Expected string value, but got nothing') } as []rune
			}
		}
		.identifier {
			// function call or variable
			mut full_identifier := []rune{}
			// get full identifier (with dots)
			for {
				token2 := tokens[*i]
				if token2.type != .identifier {
					return error('Expected identifier in value, but got `${token2.type}`')
				}
				full_identifier << (token2.value or {
					return error('Expected identifier in value, but got nothing')
				} as []rune)
				i++
				if i >= tokens.len {
					break
				}
				token3 := tokens[*i]
				if token3.type == .period {
					full_identifier << `.`
					i++
					if i >= tokens.len {
						return error('Expected identifier after `.`, but reached end of file')
					}
					continue
				} else if token3.type == .open_parens {
					// function call
					return handle_function_call(tokens, full_identifier, mut i)!
				} else {
					// variable
					return Variable{
						name: full_identifier
					}
				}
			}
			// variable
			return Variable{
				name: full_identifier
			}
		}
		else {
			return error('Unexpected token in value: `${token.type}`')
		}
	}
}

fn handle_function_call(tokens []SecondTokenizerToken, name []rune, mut i &int) !FunctionCall {
	mut func_call := FunctionCall{}
	func_call.name = name
	// extract arguments (open_parens already consumed)
	// arguments are separated by commas, and can be single function calls, variables, numbers or strings
	for {
		if i >= tokens.len {
			return error('Expected argument or `)` after `(`, but reached end of file')
		}
		token := tokens[*i]
		if token.type == .close_parens {
			// end of arguments
			i++
			break
		} else {
			func_call.arguments << handle_value(tokens, token, mut i)!
		}
		if i >= tokens.len {
			return error('Expected `)` after argument, but reached end of file')
		}
		token2 := tokens[*i]
		match token2.type {
			.comma {
				// another argument
				i++
				continue
			}
			.close_parens {
				// end of arguments
				i++
				break
			}
			else {
				return error('Expected `,` or `)` after argument, but got `${token2.type}`')
			}
		}
	}

	return func_call
}
