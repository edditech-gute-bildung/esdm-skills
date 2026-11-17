# esdm-skills

Forks of [Matt Pocock's skills](https://github.com/mattpocock/skills) that use an ESDM model as the project's domain model, in place of a hand-written `GLOSSARY.md`.

The forks keep the upstream names and layout, so they replace Matt's skills of the same name:

`domain-modeling`, `grill-with-docs`, `improve-codebase-architecture`, `setup-matt-pocock-skills`, `tdd`, `to-spec`, `triage`

Use them together with Matt's other skills. They don't replace the whole set.

## Install

Install with the [`skills`](https://www.npmjs.com/package/skills) CLI, from the project root.

### Into a project without Matt Pocock's skills

```sh
npx skills add mattpocock/skills
npx skills add edditech-gute-bildung/esdm-skills
```

Then run `/setup-matt-pocock-skills` in your agent.

The order matters: the second command writes the forks over Matt's skills of the same name.

### Into a project that already has Matt Pocock's skills

1. Install the forks over the existing skills:

   ```sh
   npx skills add edditech-gute-bildung/esdm-skills
   ```

   This replaces the seven skills above in `.agents/skills/` and points their entries in `skills-lock.json` to this repo. All other installed skills stay as they are.

2. Run `/setup-matt-pocock-skills` again, even if you ran Matt's version before. Your answers in `docs/agents/` stand, and it then sets up the ESDM part:
   - the pinned `esdm` binary
   - the model directory and `docs/agents/domain.md`
   - migration of a hand-written `GLOSSARY.md` (or a legacy `CONTEXT.md`)
   - an optional CI workflow

3. Commit the changed skill folders, `skills-lock.json`, and the files the setup wrote. If you chose the repo-local `esdm` install, collaborators run `scripts/fetch-esdm.sh` once after cloning.

### Keeping the forks installed

`npx skills add mattpocock/skills` installs Matt's originals again and overwrites the forks. To add more of Matt's skills, name them:

```sh
npx skills add mattpocock/skills --skill <name>
```

If you re-add the whole set, run `npx skills add edditech-gute-bildung/esdm-skills` afterwards.

To see the skills in this repo without installing anything, run `npx skills add edditech-gute-bildung/esdm-skills --list`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
