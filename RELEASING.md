# Releasing

Published to Hex as `vaartix`. Hex has no trusted publishing yet, so releases are published from your
computer (or with a key kept only in a protected GitHub environment).

## One-time setup

1. `mix hex.user register` (as Vaartix, with the support@ address) and turn on 2FA at hex.pm.

## Each release

1. Update `@version` in `mix.exs` and move the "Unreleased" notes in `CHANGELOG.md`. Merge to `main`.
2. Create a GitHub release with the tag `v<version>` on `main`.
3. On your computer: `git checkout v<version> && mix deps.get && mix test && mix hex.publish`
   (it shows the package contents and asks for your password and 2FA code).
