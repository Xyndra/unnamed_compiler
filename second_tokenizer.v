module main

import v.reflection

enum AdvancedTokenType {
	identifier
	keyword
	number
	newline
	open_parens  // (
	close_parens // )
	open_brace   // {
	close_brace  // }
	open_angle   // <
	close_angle  // >
	arrow        // ->
	pin          // '...
	comma        // ,
	period       // .
	string       // "..." or ""..."..."" etc.
}

type SecondTokenizerValue = []rune | Keyword

struct SecondTokenizerToken {
	type   AdvancedTokenType
	value  ?SecondTokenizerValue
	line   int
	column int
}

const keywords = (reflection.get_enums().filter(it.name == 'Keyword').first().sym.info as reflection.Enum).vals.map(it.runes())

fn retokenize(tokens []FirstTokenizerToken) ![]SecondTokenizerToken {
	mut new_tokens := []SecondTokenizerToken{}
	mut i := 0
	for i < tokens.len {
		t1 := tokens[i]
		i++
		match t1.type {
			.alphanumeric {
				if t1.value in keywords {
					new_tokens << SecondTokenizerToken{
						type:   .keyword
						value:  Keyword.from(t1.value.string())!
						line:   t1.line
						column: t1.column
					}
				} else {
					new_tokens << SecondTokenizerToken{
						type:   .identifier
						value:  t1.value
						line:   t1.line
						column: t1.column
					}
				}
			}
			.numeric {
				new_tokens << SecondTokenizerToken{
					type:   .number
					value:  t1.value
					line:   t1.line
					column: t1.column
				}
			}
			.newline {
				new_tokens << SecondTokenizerToken{
					type:   .newline
					value:  none
					line:   t1.line
					column: t1.column
				}
			}
			.open_parens {
				new_tokens << SecondTokenizerToken{
					type:   .open_parens
					value:  none
					line:   t1.line
					column: t1.column
				}
			}
			.close_parens {
				new_tokens << SecondTokenizerToken{
					type:   .close_parens
					value:  none
					line:   t1.line
					column: t1.column
				}
			}
			.open_brace {
				new_tokens << SecondTokenizerToken{
					type:   .open_brace
					value:  none
					line:   t1.line
					column: t1.column
				}
			}
			.close_brace {
				new_tokens << SecondTokenizerToken{
					type:   .close_brace
					value:  none
					line:   t1.line
					column: t1.column
				}
			}
			.open_angle {
				new_tokens << SecondTokenizerToken{
					type:   .open_angle
					value:  none
					line:   t1.line
					column: t1.column
				}
			}
			.close_angle {
				new_tokens << SecondTokenizerToken{
					type:   .close_angle
					value:  none
					line:   t1.line
					column: t1.column
				}
			}
			.dash {
				if i < tokens.len && tokens[i].type == .close_angle {
					// it's an arrow
					// consume the next token
					i++
					new_tokens << SecondTokenizerToken{
						type:   .arrow
						value:  none
						line:   t1.line
						column: t1.column
					}
				} else {
					return error('second_tokenizer: unexpected dash token at line ${t1.line}, column ${t1.column}')
				}
			}
			.apostrophe {
				// it's a pin
				if i < tokens.len && (tokens[i].type == .period || tokens[i].type == .alphanumeric) {
					// consume the next token
					new_tokens << SecondTokenizerToken{
						type:   .pin
						value:  tokens[i].value
						line:   t1.line
						column: t1.column
					}
					i++
				} else {
					return error('second_tokenizer: unexpected token after apostrophe at line ${t1.line}, column ${t1.column}')
				}
			}
			.comma {
				new_tokens << SecondTokenizerToken{
					type:   .comma
					value:  none
					line:   t1.line
					column: t1.column
				}
			}
			.period {
				new_tokens << SecondTokenizerToken{
					type:   .period
					value:  none
					line:   t1.line
					column: t1.column
				}
			}
			.quotation {
				// it's a string
				mut opening_quotes := 1
				for i < tokens.len && tokens[i].type == .quotation {
					opening_quotes++
					i++
				}
				mut string_content := []rune{}
				mut closed := false
				for i < tokens.len {
					if tokens[i].type == .quotation {
						// check if it's the closing quotes
						mut closing_quotes := 1
						mut j := i + 1
						for j < tokens.len && tokens[j].type == .quotation {
							closing_quotes++
							j++
						}
						if closing_quotes >= opening_quotes {
							// it's the closing quotes
							i = i + closing_quotes
							new_tokens << SecondTokenizerToken{
								type:   .string
								value:  string_content
								line:   t1.line
								column: t1.column
							}
							closed = true
							break
						} else {
							// it's part of the string
							string_content << tokens[i].value
							i++
							// TODO: optimize by adding all the consecutive quotations at once
						}
					} else {
						string_content << tokens[i].value
						i++
					}
				}
				if !closed {
					return error('second_tokenizer: unterminated string starting at line ${t1.line}, column ${t1.column}')
				}
			}
			.hashtag {
				// it's a comment, consume until the end of the line
				for i < tokens.len && tokens[i].type != .newline {
					i++
					// ignore comments
				}
			}
			.whitespace {
				// ignore
			}
		}
	}

	return new_tokens
}
