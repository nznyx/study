.PHONY: setup serve build lint lint-check

setup:
	python3 -m venv venv
	. venv/bin/activate && pip install --upgrade pip && pip install -e .
	npm install

serve:
	. venv/bin/activate && mkdocs serve

build:
	. venv/bin/activate && mkdocs build

lint:
	[ -d venv ] && . venv/bin/activate; mkdocs build --strict
	npx ls-lint
	npx markdownlint --fix "docs/**/*.md"

lint-check:
	[ -d venv ] && . venv/bin/activate; mkdocs build --strict
	npx ls-lint
	npx markdownlint "docs/**/*.md"