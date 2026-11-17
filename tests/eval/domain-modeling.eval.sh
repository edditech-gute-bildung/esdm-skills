#!/usr/bin/env bash
# /domain-modeling adds renewing a loan to lending. Passes when the model
# lints, a new element lives under model/lending/, and GLOSSARY.md is
# regenerated: the generated marker line, then what `esdm glossary` prints.
# The new lending documents mustn't say "book" or "books", which lending
# avoids: there a book is cataloging's title, and lending's word is "copy". A
# reference to cataloging's book aggregate or its events doesn't count.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

judge() {
  local repo="$1/repo" new
  expect "the model lints" quietly "$repo/.tools/esdm" lint -d "$repo/model" || return 1
  new="$(new_lending_documents "$repo")"
  expect "a new element lives under model/lending/" test -n "$new" || return 1
  expect "the new lending documents avoid \"book\"" avoid_book <<<"$new" || return 1
  expect "GLOSSARY.md is regenerated" quietly diff -q "$repo/GLOSSARY.md" \
    <(echo "$EVAL_GLOSSARY_MARKER"; "$repo/.tools/esdm" glossary -d "$repo/model") || return 1
}

# avoid_book: no line of stdin says "book" outside a reference to cataloging's
# book; the lines that do are printed.
avoid_book() {
  ! grep -vE 'aggregate: *book *$|cataloging/book/' | grep -iwE 'books?'
}

# new_lending_documents <repo>: the YAML documents under model/lending/ whose
# kind and name no document there had in the fixture commit, as written. The
# fixture commit is the root one, in case the run committed. Needs ruby.
new_lending_documents() {
  (
    cd "$1" || exit 1
    ruby -ryaml -e '
      # Psych 4 made load safe, which refuses the dates a document may hold.
      def load(raw)
        YAML.respond_to?(:unsafe_load) ? YAML.unsafe_load(raw) : YAML.load(raw)
      end
      def documents(text)
        text.split(/^---[ \t]*$/).map do |raw|
          doc = load(raw)
          [[doc["kind"], doc["name"]], raw] if doc.is_a?(Hash)
        end.compact
      end
      fixture = `git rev-list --max-parents=0 HEAD`.split.last
      old = `git ls-tree -r --name-only #{fixture} model/lending/`.split("\n").flat_map do |file|
        documents(`git show #{fixture}:#{file}`).map(&:first)
      end
      Dir.glob("model/lending/**/*.yaml").sort.each do |file|
        documents(File.read(file)).each { |key, raw| puts raw unless old.include?(key) }
      end
    '
  )
}

run_scenario domain-modeling domain-modeling "add renewing a loan to lending"
