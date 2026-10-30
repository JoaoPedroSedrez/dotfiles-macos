# Secretive

> **Not in use right now.** Secretive isn't installed (no cask in
> `configs/nix-darwin/homebrew.nix`) and `configs/ssh/config` uses the
> stock macOS agent. Work commits are signed with a regular key instead;
> see [Work commit signing](#work-commit-signing) below. The rest of this
> doc is how to switch to Secretive.

[Secretive](https://github.com/maxgoedjen/secretive) generates SSH keys
inside the Mac's Secure Enclave: they can't be exported, and every use
asks for Touch ID.

## Work commit signing

px-center requires signed commits (since 2026-11-03). Inside `~/Work`,
`configs/git/work.gitconfig` signs every commit and tag with
`~/.ssh/id_ed25519_px_signing`, an ed25519 key whose passphrase lives in
the login Keychain. Only the public half is in this repo
(`configs/git/allowed_signers_work`, for `git log --show-signature`).

- The key is registered as a **Signing Key** on the `JoaoPedroSedrezPX`
  GitHub account, and `joao.sedrez@px.center` is verified there.
- `configs/shell/30_ssh_agent.sh` runs `ssh-add --apple-load-keychain` in
  new shells, since `ssh-keygen -Y sign` ignores `AddKeysToAgent`.
- New machine: `ssh-keygen -t ed25519 -C joao.sedrez@px.center -f
  ~/.ssh/id_ed25519_px_signing`, then `ssh-add --apple-use-keychain` on
  it, register the new `.pub` on GitHub and replace the line in
  `allowed_signers_work`.

We don't need SSH for GitHub itself: git talks to GitHub over HTTPS with
`gh` as the credential helper (`configs/git/gitconfig`). Secretive covers
SSH into servers and, optionally, commit signing.

## Trade-off

One key per machine, and it can't be backed up or copied. Lose or wipe
the Mac and the key is gone. That's fine for what it's used for here:
make a new key on the new machine and register it wherever the old one
was.

## Create a key

1. Open **Secretive** and click **+**. Name it after the machine (e.g.
   `work-mbp`) and leave **Require authentication** on.
2. Select the key and copy its public key (the `ecdsa-sha2-nistp256 ...`
   line). Secretive also writes it to
   `~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/PublicKeys/`.
3. Check the agent sees it:

   ```sh
   ssh-add -l
   ```

## Register it on GitHub

GitHub → Settings → **SSH and GPG keys** → **New SSH key**, paste the
public key, and pick the type:

- **Authentication key**: only if you want SSH access to GitHub (e.g.
  `git@github.com:` remotes). HTTPS + `gh` doesn't need it.
- **Signing key**: needed for the next section. The same key can be added
  twice, once per type.

## Optional: sign commits

Signing is off by default. To turn it on, uncomment the signing block in
`configs/git/gitconfig` and paste your public key after `key::`:

```gitconfig
[user]
	signingkey = key::ecdsa-sha2-nistp256 AAAA...
[gpg]
	format = ssh
[commit]
	gpgsign = true
```

Each commit then asks for Touch ID. GitHub shows it as **Verified** once
the key is registered as a signing key.

To make `git log --show-signature` verify locally too, add an allowed
signers file:

```sh
echo "$(git config user.email) ecdsa-sha2-nistp256 AAAA..." > ~/.config/git/allowed_signers
git config --global gpg.ssh.allowedSignersFile ~/.config/git/allowed_signers
```
