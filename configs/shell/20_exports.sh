# exports.sh - meant to be sourced in .bash_profile/.zshrc

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export EDITOR="nvim"
export XDG_CONFIG_HOME="$HOME/.config"
export LESS="-R"  # Enable colors in less (avoid --mouse, breaks text selection)
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1  # Disable Claude Code auto-updater and telemetry

# -- Homebrew (needed below for brew --prefix)
if [ -f "/opt/homebrew/bin/brew" ]; then
   eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# After brew shellenv, which prepends /opt/homebrew/bin, so the gh wrapper
# in ~/.local/bin (configs/bin/gh) wins over Homebrew's gh.
export PATH="$HOME/.local/bin:$PATH"

# -- Build deps for `mise install php` (compiled from source by vfox-php).
# These Homebrew formulae are keg-only, so without this configure picks up
# macOS's bison 2.3 and can't find openssl/icu/readline via pkg-config.
_brew_opt="$(brew --prefix)/opt"
export PATH="$_brew_opt/bison/bin:$_brew_opt/re2c/bin:$PATH"
for _f in openssl@3 icu4c libiconv readline libzip oniguruma gd libsodium curl zlib bzip2 libxml2 libpq krb5 libedit gmp; do
  [ -d "$_brew_opt/$_f/lib/pkgconfig" ] && PKG_CONFIG_PATH="$_brew_opt/$_f/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
done
export PKG_CONFIG_PATH
unset _brew_opt _f

# -- Android / React Native
export ANDROID_HOME="$(brew --prefix)/share/android-commandlinetools"
# Without this the newer cmdline-tools honour XDG_CONFIG_HOME and look for
# AVDs under ~/.config/.android, while the emulator binary uses ~/.android —
# each tool then sees a different set of AVDs.
export ANDROID_USER_HOME="$HOME/.android"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
# Build only for the arch this Mac runs on — skips x86_64/armeabi NDK builds
export ORG_GRADLE_PROJECT_reactNativeArchitectures=arm64-v8a
