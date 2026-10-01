# Load the same per-user nvm and default Node used by Bash, including fish -c.
set -gx NVM_DIR $HOME/.nvm
if test -s "$NVM_DIR/nvm.sh"
    nvm use --silent default
end
