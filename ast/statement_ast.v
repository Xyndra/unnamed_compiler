module ast

pub type Value = Number | String | Variable | FunctionCall
pub type Statement = Value | IfStatement | IfMatchStatement | VariableDeclaration | VariableAssignment

pub enum LifetimeType {
	scope_pinned // '. - pinned to current scope
	custom       // 'identifier - custom lifetime (future feature)
}

pub struct Lifetime {
pub:
	type LifetimeType
	name ?[]rune // For custom lifetimes
}

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

pub struct VariableDeclaration {
pub mut:
	name     []rune
	lifetime Lifetime
	value    Value
}

pub struct VariableAssignment {
pub mut:
	name  []rune
	value Value
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
	condition Value
	body      Scope
	else_body ?Scope
}

pub struct IfMatchBranch {
pub mut:
	arguments []Value
	body      Statement
}

pub struct IfMatchStatement {
pub mut:
	function_name []rune
	branches      []IfMatchBranch
	else_body     ?Scope
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
				// i currently points at the closing brace
				// increment to position after it
				i++
				break
			}
			token2.type == .newline {
				// ignore newlines in scope body
				continue
			}
			token2.type == .keyword {
				value := token2.value or { return error('Expected keyword, but got nothing') } as Keyword
				match value {
					.var {
						// Variable declaration
						statements << handle_variable_declaration(tokens, token2, mut i)!
					}
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
					.if {
						// Handle if statement
						i++
						if i >= tokens.len {
							return error('Expected `(` or identifier after `if` keyword, but reached end of file')
						}
						token3 := tokens[*i]
						// Check if it's a match-style if (identifier followed by {)
						if token3.type == .identifier {
							// Match-style if: if funcname { args -> body ... }
							func_name := token3.value or {
								return error('Expected function name, but got nothing')
							} as []rune
							i++

							// Expect opening brace
							if i >= tokens.len {
								return error('Expected `{` after function name in match-style if, but reached end of file')
							}
							token4 := tokens[*i]
							if token4.type != .open_brace {
								return error('Expected `{` after function name in match-style if, but got `${token4.type}`')
							}
							i++

							// Parse branches
							mut branches := []IfMatchBranch{}
							for {
								if i >= tokens.len {
									return error('Expected branch or `}` in match-style if, but reached end of file')
								}
								branch_token := tokens[*i]

								// Check for closing brace or else
								if branch_token.type == .close_brace {
									i++
									break
								}
								if branch_token.type == .keyword {
									if kw := branch_token.value {
										if kw is Keyword && kw == .else {
											break
										}
									}
								}
								if branch_token.type == .newline {
									i++
									continue
								}

								// Parse arguments before ->
								mut args := []Value{}
								for {
									if i >= tokens.len {
										return error('Expected argument or `->` in match branch, but reached end of file')
									}
									arg_token := tokens[*i]

									if arg_token.type == .arrow {
										// End of arguments
										i++
										break
									}

									// Parse argument value
									arg_val := handle_value(tokens, arg_token, mut i)!
									args << arg_val

									// Expect comma or arrow
									if i >= tokens.len {
										return error('Expected `,` or `->` after argument, but reached end of file')
									}
									next_token := tokens[*i]
									if next_token.type == .comma {
										i++
										continue
									} else if next_token.type == .arrow {
										i++
										break
									} else {
										return error('Expected `,` or `->` after argument, but got `${next_token.type}`')
									}
								}

								// Parse body (single statement)
								if i >= tokens.len {
									return error('Expected body after `->` in match branch, but reached end of file')
								}
								body_token := tokens[*i]
								body_stmt := handle_single_statement(tokens, body_token, mut
									i)!

								branches << IfMatchBranch{
									arguments: args
									body:      body_stmt
								}

								// Expect newline after branch
								if i < tokens.len && tokens[*i].type == .newline {
									i++
								}
							}

							// Check for else keyword
							mut else_body := ?Scope(none)
							if i < tokens.len {
								next_token := tokens[*i]
								if next_token.type == .keyword {
									if kw := next_token.value {
										if kw is Keyword && kw == .else {
											// Found else keyword
											i++
											// Expect opening brace for else body
											if i >= tokens.len {
												return error('Expected `{` after `else` keyword, but reached end of file')
											}
											else_token := tokens[*i]
											if else_token.type != .open_brace {
												return error('Expected `{` after `else` keyword, but got `${else_token.type}`')
											}
											// Parse else body
											else_body = handle_scope(tokens, else_token, mut
												i)!
										}
									}
								}
							}

							statements << IfMatchStatement{
								function_name: func_name
								branches:      branches
								else_body:     else_body
							}
						} else if token3.type == .open_parens {
							// Regular if statement: if (condition) { ... }
							i++
							// Parse condition (should be a function call or value)
							if i >= tokens.len {
								return error('Expected condition after `(`, but reached end of file')
							}
							condition_token := tokens[*i]
							condition := handle_value(tokens, condition_token, mut i)!
							// Expect closing parenthesis
							if i >= tokens.len {
								return error('Expected `)` after if condition, but reached end of file')
							}
							token4 := tokens[*i]
							if token4.type != .close_parens {
								return error('Expected `)` after if condition, but got `${token4.type}`')
							}
							i++
							// Expect opening brace for body
							if i >= tokens.len {
								return error('Expected `{` after if condition, but reached end of file')
							}
							token5 := tokens[*i]
							if token5.type != .open_brace {
								return error('Expected `{` after if condition, but got `${token5.type}`')
							}
							// Parse if body
							if_body := handle_scope(tokens, token5, mut i)!

							// Check for else keyword
							mut else_body := ?Scope(none)
							if i < tokens.len {
								next_token := tokens[*i]
								if next_token.type == .keyword {
									if kw := next_token.value {
										if kw is Keyword {
											if kw == .else {
												// Found else keyword
												i++
												// Expect opening brace for else body
												if i >= tokens.len {
													return error('Expected `{` after `else` keyword, but reached end of file')
												}
												else_token := tokens[*i]
												if else_token.type != .open_brace {
													return error('Expected `{` after `else` keyword, but got `${else_token.type}`')
												}
												// Parse else body
												else_body = handle_scope(tokens, else_token, mut
													i)!
											}
										}
									}
								}
							}

							statements << IfStatement{
								condition: condition
								body:      if_body
								else_body: else_body
							}
						} else {
							return error('Expected `(` or identifier after `if` keyword, but got `${token3.type}`')
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

fn handle_variable_declaration(tokens []SecondTokenizerToken, token SecondTokenizerToken, mut i &int) !Statement {
	// var name'lifetime = value
	i++
	if i >= tokens.len {
		return error('Expected variable name after `var` keyword, but reached end of file')
	}
	
	name_token := tokens[*i]
	if name_token.type != .identifier {
		return error('Expected variable name after `var` keyword, but got `${name_token.type}`')
	}
	var_name := name_token.value or { return error('Expected variable name, but got nothing') } as []rune
	i++
	
	// Check for lifetime specifier
	if i >= tokens.len {
		return error('Expected lifetime specifier or `=` after variable name, but reached end of file')
	}
	
	mut lifetime := Lifetime{
		type: .scope_pinned
		name: none
	}
	
	lifetime_token := tokens[*i]
	if lifetime_token.type == .pin {
		// Has lifetime specifier
		pin_value := lifetime_token.value or { return error('Expected lifetime value, but got nothing') } as []rune
		if pin_value.string() != '.' {
			// Custom lifetime (future feature)
			lifetime = Lifetime{
				type: .custom
				name: pin_value
			}
		}
		i++
	}
	
	// Expect equals sign
	if i >= tokens.len {
		return error('Expected `=` after variable name/lifetime, but reached end of file')
	}
	equals_token := tokens[*i]
	if equals_token.type != .equals {
		return error('Expected `=` after variable name/lifetime, but got `${equals_token.type}`')
	}
	i++
	
	// Parse value
	if i >= tokens.len {
		return error('Expected value after `=`, but reached end of file')
	}
	value := handle_value(tokens, tokens[*i], mut i)!
	
	return VariableDeclaration{
		name:     var_name
		lifetime: lifetime
		value:    value
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
		// variable assignment
		if i >= tokens.len {
			return error('Expected value after `=`, but reached end of file')
		}
		value := handle_value(tokens, tokens[*i], mut i)!
		
		return VariableAssignment{
			name:  full_identifier
			value: value
		}
	}
	return error('Expected `(` for function call or `=` for variable assignment')
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
					// function call - consume the open_parens first
					i++
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
