module ast

pub struct Import {
pub mut:
	mod []rune
	as  []rune
}

pub struct FileAST {
pub mut:
	module    []rune
	imports   []Import
	functions []Function
}

pub fn build_ast(tokens []SecondTokenizerToken) !FileAST {
	mut file_ast := FileAST{}
	mut i := -1

	for i < tokens.len - 1 {
		i++
		token := tokens[i]
		match true {
			file_ast.module.len == 0 && token.type == .keyword
				&& token.value == ?SecondTokenizerValue(Keyword.module) {
				file_ast.module = handle_module(tokens, token, mut i) or { return err }
			}
			file_ast.module.len == 0 {
				return error('Expected `module` keyword at the start of the file, but got `${token.type}`')
			}
			token.type == .keyword && token.value == ?SecondTokenizerValue(Keyword.module) {
				return error('Multiple `module` declarations are not allowed, but got another one')
			}
			token.type == .keyword && token.value == ?SecondTokenizerValue(Keyword.import) {
				// match import declarations
				file_ast.imports << handle_import(tokens, token, mut i) or { return err }
			}
			token.type == .keyword && token.value == ?SecondTokenizerValue(Keyword.fn) {
				file_ast.functions << handle_function(tokens, token, mut i) or {
					dump(tokens[i])
					return err
				}
			}
			token.type == .newline {
				// ignore newlines
				continue
			}
			else {
				// TODO: turn this into an error after implementing all other AST nodes
				continue
			}
		}
	}

	return file_ast
}

fn handle_module(tokens []SecondTokenizerToken, token SecondTokenizerToken, mut i &int) ![]rune {
	mut module_name := []rune{}
	i++
	for {
		if i >= tokens.len {
			return error('Expected module name after `module` keyword, but reached end of file')
		}
		token2 := tokens[*i]

		if token2.type != .identifier {
			return error('Expected module name after `module` keyword, but got `${token.type}`')
		}
		module_name << (token2.value or {
			return error('Expected module name after `module` keyword, but got nothing')
		} as []rune)
		i++
		if i >= tokens.len {
			break
		}
		token3 := tokens[*i]
		match token3.type {
			.period {
				module_name << `.`
				i++
				continue
			}
			.newline {
				// end of module declaration
				break
			}
			else {
				return error('Unexpected token after `module` declaration: `${token3.type}`')
			}
		}
	}
	return module_name
}

fn handle_import(tokens []SecondTokenizerToken, token SecondTokenizerToken, mut i &int) !Import {
	mut imp := Import{}
	i++
	for {
		if i >= tokens.len {
			return error('Expected module name after `import` keyword, but reached end of file')
		}
		token2 := tokens[*i]

		if token2.type != .identifier {
			return error('Expected module name after `import` keyword, but got `${token.type}`')
		}
		imp.mod << (token2.value or {
			return error('Expected module name after `import` keyword, but got nothing')
		} as []rune)
		i++
		if i >= tokens.len {
			return error('Expected `as` keyword after import declaration, but reached end of file')
		}
		token3 := tokens[*i]
		match token3.type {
			.period {
				imp.mod << `.`
				i++
				continue
			}
			.keyword {
				if token3.value == ?SecondTokenizerValue(Keyword.as) {
					i++
					if i >= tokens.len {
						return error('Expected alias name after `as` keyword, but reached end of file')
					}
					token4 := tokens[*i]
					if token4.type != .identifier {
						return error('Expected alias name after `as` keyword, but got `${token4.type}`')
					}
					imp.as = token4.value or {
						return error('Expected alias name after `as` keyword, but got nothing')
					} as []rune
					i++
					if i >= tokens.len {
						break
					}
					token5 := tokens[*i]
					if token5.type != .newline {
						return error('Expected newline after import alias declaration, but got `${token5.type}`')
					}
					break
				} else {
					return error('Unexpected keyword `${token3.value}` in import declaration')
				}
			}
			else {
				return error('Unexpected token after `import` declaration: `${token3.type}`')
			}
		}
	}
	return imp
}
