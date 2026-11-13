# Functional core, imperative shell

Domain rules are pure functions over plain values, with no I/O. Storage, clocks and notifications live in a thin imperative shell that calls them. We chose this so every rule in the model can be tested with plain values, without a database or fakes.
