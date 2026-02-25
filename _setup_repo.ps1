Set-Location "D:\Coding\daily-update"
git init
git add -A
git commit -m "initial commit"
gh repo create daily-update --public --description "Windows 11 daily package manager update toolkit" --source=. --remote=origin --push
