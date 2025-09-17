module main

import os

fn main() {
	file := 'samples/simple.xy'
	first_tokens := tokenize(os.read_file(file)!.split_into_lines().map(it.runes()))
	second_tokens := retokenize(first_tokens) or {
		eprintln('Error during retokenization: ${err}')
		return
	}
	println(second_tokens)
}
