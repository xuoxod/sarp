# 1) ensure you're on main and up to date
git checkout main
git pull origin main

# 2) create a feature branch
git checkout -b ci/add-workflow

# 3) stage the files I added (or 'git add .' to include everything)
git add .github/workflows/ci.yml
git add docs/GH_ACTIONS_TUTORIAL.md
git add scripts/tests/run_all.sh
# if you added any other new files, include them too, e.g.:
# git add .gitignore README.md

# 4) commit
git commit -m "ci: add GitHub Actions workflow, tutorial, and test runner"

# 5) push the branch to origin
git push -u origin ci/add-workflow

# 6) (optional) open a PR in your browser using GitHub CLI (if you have it)
# This creates a PR with the branch and opens an interactive prompt
gh pr create --fill --base main --head ci/add-workflow