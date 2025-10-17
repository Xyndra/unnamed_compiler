module main

import os
import ast

fn main() {
	file := 'samples/simple.xy'
	first_tokens := ast.tokenize(os.read_file(file)!.split_into_lines().map(it.runes()))
	second_tokens := ast.retokenize(first_tokens) or {
		eprintln('Error during retokenization: ${err}')
		return
	}
	file_ast := ast.build_ast(second_tokens) or {
		eprintln('Error during AST building: ${err}')
		return
	}
	println('AST built successfully, running interpreter...')
	interpret(file_ast) or {
		eprintln('Error during interpretation: ${err}')
		return
	}
}
