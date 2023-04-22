#!/bin/bash
set -euo pipefail

# Install required packages
pacman -Syu --noconfirm --needed sudo

# Added builder as seen in edlanglois/pkgbuild-action
# mainly for permissions
useradd builder -m
# When installing dependencies, makepkg will use sudo
# Give user `builder` passwordless sudo access
echo "builder ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers

# Give all users (particularly builder) full access to these files
chmod -R a+rw .

sudoCMD="sudo -u builder"

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
${sudoCMD} mkdir "${INPUT_CONFDIR:-tmpConf}"

# Work on makepkg config
if [ -n "${INPUT_TPLMAKEPKGCONF:-}" ]; then
    makepkgFile="${INPUT_CONFDIR:-tmpConf}/${INPUT_ARCHITECTURE}_makepkg.conf"

    # Copy makepkg template to output directory
    ${sudoCMD} cp "${INPUT_TPLMAKEPKGCONF}" ${makepkgFile}

    # Update makepkg to use correct architecture
    if [[ "${INPUT_ARCHITECTURE:-'generic'}" == 'generic' ]]; then
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
    pacmanFile="${INPUT_CONFDIR:-tmpConf}/${INPUT_ARCHITECTURE}_pacman.conf"

    # Copy pacman template to output directory
    ${sudoCMD} cp "${INPUT_TPLPACMANCONF}" ${pacmanFile}

    if [ -n "${INPUT_REPOTAGKEY:-}" ]; then
        ${sudoCMD} sed -i "s/${INPUT_REPOTAGKEY:-}/${INPUT_REPOTAG:-${INPUT_ARCHITECTURE}}/g" ${pacmanFile}
    fi

    # Assume pacman will be using the gh release repo
    ghRepoServer="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/releases/download/${INPUT_REPOTAG:-}"

    if [ -n "${INPUT_REPOSERVERKEY:-}" ]; then
        ${sudoCMD} sed -i "s/${INPUT_REPOSERVERKEY:-}/${INPUT_REPOSERVER:-${ghRepoServer}}/g" ${pacmanFile}
    fi

    echo "pacmanConf=${pacmanFile}" >>$GITHUB_OUTPUT
fi

# Work on package PKGBUILD
if [[ "${INPUT_UPDATEPKG:-false}" == true ]]; then
    if [ -n "${INPUT_PKG:-}" ]; then
        if [[ "${INPUT_ARCHITECTURE:-'generic'}" == 'generic' ]]; then
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
