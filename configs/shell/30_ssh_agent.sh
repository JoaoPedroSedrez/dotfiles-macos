# 30_ssh_agent.sh - meant to be sourced in .bash_profile/.zshrc

# Load keys whose passphrase is saved in the login Keychain into the agent,
# so `git commit` in ~/Work can sign without prompting (and GUI clients
# don't fail) after a reboot. ssh-keygen -Y sign doesn't read ~/.ssh/config,
# so AddKeysToAgent there doesn't cover it. Only runs while the signing key
# isn't loaded yet; /usr/bin because --apple-load-keychain is Apple-only.
if [[ $- == *i* ]] && [ -f ~/.ssh/id_ed25519_px_signing ]; then
  if ! /usr/bin/ssh-add -l 2>/dev/null | grep -q "joao.sedrez@px.center"; then
    /usr/bin/ssh-add --apple-load-keychain -q 2>/dev/null
  fi
fi
