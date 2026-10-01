function nvm --description 'Manage Node.js versions with nvm-sh'
    bass source "$NVM_DIR/nvm.sh" --no-use ';' nvm $argv
end
