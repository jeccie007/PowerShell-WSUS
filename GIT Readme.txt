
GIT SETUP 

ssh-keygen -t ed25519 -C "jeccie007@outlook.com"


git config --global user.name "Jeccie 007"


…or create a new repository on the command line
echo "# PowerShell-WSUS" >> README.md
git init
git add README.md
git commit -m "first commit"
git branch -M main
git remote add origin https://github.com/jeccie007/PowerShell-WSUS.git
git push -u origin main

…or push an existing repository from the command line
git remote add origin https://github.com/jeccie007/PowerShell-WSUS.git
git branch -M main
git push -u origin main

