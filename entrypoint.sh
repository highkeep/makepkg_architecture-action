#!/bin/bash
set -euo pipefail

# Sanity Checks
if [ -n "${INPUT_TPLMAKEPKGCONF:-}" ]; then
    [ -f "${INPUT_TPLMAKEPKGCONF}" ] || exit 1
fi

if [ -n "${INPUT_TPLPACMANCONF:-}" ]; then
    [ -f "${INPUT_TPLPACMANCONF}" ] || exit 1
fi

##################################################

# Install required packages
pacman -Syu --noconfirm --needed sudo

# ls -l within ubuntu-latest shows owner of clone is runner and group is docker
# id of runner user: uid=1001(runner) gid=123(docker) groups=123(docker),4(adm),101(systemd-journal)
# So lets match that from now on...

# Add docker group
groupadd -g 123 docker

# Add runner user
useradd runner -m -u 1001 -g 123
# When installing dependencies, makepkg will use sudo
# Give user `runner` passwordless sudo access
echo "runner ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers

# Set up sudo cmd to make life a little easier
sudoCMD="sudo -H -u runner"

function setMarch() {
    ${sudoCMD} sed -i -r "s/(march=)[A-Za-z0-9-]+(\s?)/\1${1}\2/g" ${2}
}

function setMtune() {
    ${sudoCMD} sed -i -r "s/(mtune=)[A-Za-z0-9-]+(\s?)/\1${1}\2/g" ${2}
}

function setTargetCpu() {
    ${sudoCMD} sed -i -r "s/(target-cpu=)[A-Za-z0-9-]+(\s?)/\1${1}\2/g" ${2}
}

# Setup output directory
${sudoCMD} mkdir "${INPUT_CONFOUTDIR:-tmpConf}"

# Work on makepkg config
if [ -n "${INPUT_TPLMAKEPKGCONF:-}" ]; then
    makepkgFile="${INPUT_CONFOUTDIR:-tmpConf}/${INPUT_ARCHITECTURE:-generic}_makepkg.conf"

    # Copy makepkg template to output directory
    ${sudoCMD} cp "${INPUT_TPLMAKEPKGCONF}" ${makepkgFile}

    # Update makepkg to use correct architecture
    if [[ "${INPUT_ARCHITECTURE:-generic}" == 'generic' ]]; then
        setMarch "x86-64" ${makepkgFile}
        setMtune "generic" ${makepkgFile}
        setTargetCpu "x86-64" ${makepkgFile}
    else
        setMarch "${INPUT_ARCHITECTURE}" ${makepkgFile}
        setMtune "${INPUT_ARCHITECTURE}" ${makepkgFile}
        setTargetCpu "${INPUT_ARCHITECTURE}" ${makepkgFile}
    fi

    echo "makepkgConf=${makepkgFile}" >>$GITHUB_OUTPUT
fi

# Work on pacman config
if [ -n "${INPUT_TPLPACMANCONF:-}" ]; then
    pacmanFile="${INPUT_CONFOUTDIR:-tmpConf}/${INPUT_ARCHITECTURE:-generic}_pacman.conf"

    # Copy pacman template to output directory
    ${sudoCMD} cp "${INPUT_TPLPACMANCONF}" ${pacmanFile}

    # Swap out repo tag key
    if [ -n "${INPUT_REPOTAGKEY:-REPOTAGKEY}" ]; then
        ${sudoCMD} sed -i "s/${INPUT_REPOTAGKEY:-REPOTAGKEY}/${INPUT_REPOTAG:-${INPUT_ARCHITECTURE:-generic_x86_64}}/g" ${pacmanFile}
    fi

    # Assume pacman will be using the gh release repo
    ghRepoServer="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/releases/download/${INPUT_REPOTAG:-${INPUT_ARCHITECTURE:-generic_x86_64}}"

    # Swap out repo server key
    if [ -n "${INPUT_REPOSERVERKEY:-REPOSERVERKEY}" ]; then
        ${sudoCMD} sed -i "s/${INPUT_REPOSERVERKEY:-REPOSERVERKEY}/${INPUT_REPOSERVER:-${ghRepoServer//\//\\/}}/g" ${pacmanFile}
    fi

    echo "pacmanConf=${pacmanFile}" >>$GITHUB_OUTPUT
    echo "repoTag=${INPUT_REPOTAG:-${INPUT_ARCHITECTURE:-generic_x86_64}}" >>$GITHUB_OUTPUT
    echo "repoServer=${INPUT_REPOSERVER:-${ghRepoServer//\//\\/}}" >>$GITHUB_OUTPUT
fi

# Work on package PKGBUILD
if [[ "${INPUT_UPDATEPKG:-false}" == true ]]; then
    if [ -n "${INPUT_PKG:-}" ]; then
        if [[ "${INPUT_ARCHITECTURE:-generic}" == 'generic' ]]; then
            setMarch "x86-64" ${INPUT_PKG}/PKGBUILD
            setMtune "generic" ${INPUT_PKG}/PKGBUILD
            setTargetCpu "x86-64" ${INPUT_PKG}/PKGBUILD
        else
            setMarch "${INPUT_ARCHITECTURE}" ${INPUT_PKG}/PKGBUILD
            setMtune "${INPUT_ARCHITECTURE}" ${INPUT_PKG}/PKGBUILD
            setTargetCpu "${INPUT_ARCHITECTURE}" ${INPUT_PKG}/PKGBUILD
        fi
    fi
fi
