module ast

enum SimpleTokenType {
	alphanumeric
	numeric
	newline
	equals       // =
	open_parens  // (
	close_parens // )
	open_brace   // {
	close_brace  // }
	open_angle   // <
	close_angle  // >
	dash         // -
	apostrophe   // '
	comma        // ,
	period       // .
	quotation    // "
	hashtag      // #
	whitespace   // space, tab
}

struct FirstTokenizerToken {
	type   SimpleTokenType
	value  []rune
	line   int
	column int
}

fn get_token_type(r rune) SimpleTokenType {
	if (r <= `9` && r >= `0`) || r == `-` {
		return SimpleTokenType.numeric
	}
	t := match r {
		`(` { SimpleTokenType.open_parens }
		`)` { SimpleTokenType.close_parens }
		`{` { SimpleTokenType.open_brace }
		`}` { SimpleTokenType.close_brace }
		`<` { SimpleTokenType.open_angle }
		`>` { SimpleTokenType.close_angle }
		`-` { SimpleTokenType.dash }
		`'` { SimpleTokenType.apostrophe }
		`,` { SimpleTokenType.comma }
		`.` { SimpleTokenType.period }
		`"` { SimpleTokenType.quotation }
		` `, `\t` { SimpleTokenType.whitespace }
		`#` { SimpleTokenType.hashtag }
		`=` { SimpleTokenType.equals }
		else { SimpleTokenType.alphanumeric }
	}
	return t
}

// s: A list of lines (each line is a list of runes)
pub fn tokenize(s [][]rune) []FirstTokenizerToken {
	mut tokens := []FirstTokenizerToken{}
	for l, line in s {
		mut current_token := []rune{}
		mut current_token_type := ?SimpleTokenType(none)
		mut column := 0
		for r in line {
			column++
			t := get_token_type(r)
			if current_token_type == none {
				current_token_type = t
				current_token << r
				continue
			}

			if t != current_token_type {
				match true {
					current_token_type == ?SimpleTokenType(.alphanumeric) && t == .numeric {
						// numbers may be inside alphanumeric tokens, e.g. "a1b2", but not in front. therfore, noop
					}
					current_token_type == ?SimpleTokenType(.numeric)
						&& (t == .alphanumeric || t == .period) {
						// this is to allow floating point numbers and hex/bin/oct notation. noop
						// note that this will be invalidated later in case of something like "1.2.3", "0xG" or "1a2"
					}
					else {
						tokens << FirstTokenizerToken{
							type:   current_token_type or { panic('unreachable') }
							value:  current_token
							line:   l + 1
							column: column - current_token.len
						}
						current_token_type = t
						current_token = []rune{}
					}
				}
				current_token << r
			} else if t == .alphanumeric || t == .numeric || t == .whitespace {
				// continue building the current token
				current_token << r
			} else {
				// instantly create a new token for thinks that don't make sense being grouped
				tokens << FirstTokenizerToken{
					type:   current_token_type or { panic('unreachable') }
					value:  current_token
					line:   l + 1
					column: column - current_token.len
				}
				current_token_type = t
				current_token = []rune{}
				current_token << r
			}

			continue
		}
		if current_token.len != 0 {
			tokens << FirstTokenizerToken{
				type:   current_token_type or { panic('unreachable') }
				value:  current_token
				line:   l + 1
				column: column - current_token.len
			}
		}
		tokens << FirstTokenizerToken{
			type:   .newline
			value:  [`\n`]
			line:   l + 1
			column: column + 1
		}
	}

	return tokens
}
