# local-subtensor

## Setup production environment (git deployment)

```sh
# remote server
mkdir -p ~/repos
cd ~/repos
git init --bare --initial-branch=master local-subtensor.git

mkdir -p ~/projects/local-subtensor
```

```sh
# locally
git remote add production ubuntu@<server>:~/repos/local-subtensor.git
git push production master
```

```sh
# remote server
cd ~/repos/local-subtensor.git

cat <<'EOT' > hooks/post-receive
#!/bin/bash -eux
unset GIT_INDEX_FILE
export ROOT=~
export REPO=local-subtensor
while read -r _ _ ref
do
    if [[ $ref =~ .*/master$ ]]; then
        export GIT_DIR="$ROOT/repos/$REPO.git/"
        export GIT_WORK_TREE="$ROOT/projects/$REPO/"
        git checkout -f master
        cd $GIT_WORK_TREE || exit 1
        #./deploy.sh
    else
        echo "Doing nothing: only the master branch may be deployed on this server."
    fi
done
EOT

chmod +x hooks/post-receive
./hooks/post-receive <<< "'' '' refs/heads/master"
```
