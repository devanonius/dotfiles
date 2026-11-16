# Migrations

One-time changes for machines that installed an older version of these
dotfiles: removing a file a config no longer uses, renaming a state file,
switching a service. Stage `45-migrate` runs each pending one in name order
before configs are linked, and records it in
`~/.local/state/dotfiles/migrations.txt` so it never runs twice.

A fresh install has nothing to migrate: the first time the stage runs on a
machine it records every existing migration as done without running it.

## Writing one

`migrations/NNNN-short-name.sh`, numbered after the last one. It is sourced
by the installer, so `info`, `warn`, `changed`, `run` and `$DOTFILES_DIR`
are available. It must:

- define `migrate()`, which does the change;
- be safe to run on a machine where the change is already done (check first);
- use `run` for every command that changes the system, so `--dry-run` works;
- return non-zero only when the install must stop.
