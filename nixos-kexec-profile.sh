#!@runtimeShell@
# shellcheck shell=bash

if [ -x "@runtimeShell@" ]; then export SHELL="@runtimeShell@"; fi;

set -euo pipefail

export PATH=@path@:$PATH

build-configuration-legacy() {
    run nix-build '<nixpkgs/nixos>' -A system -I nixos-config="$1"
}

build-configuration-flake() {
    run nix build "$1.out" --no-link --print-out-paths
}

type nix > /dev/null
type nix-build > /dev/null
type jq > /dev/null
type kexec > /dev/null
type id > /dev/null

DEFAULT_TARGET="${BUILD:-/nix/var/nix/profiles/system}"

TYPE=""
BUILD=""
BOOT=n

msg() {
    echo "=====> msg:  $@" >&2
}

fail() {
    echo "=====> fail: $@" >&2
    exit 1
}

run() {
    echo "=====> run:  $@" >&2
    "$@"
}

set-target() {
    if ! [ -z "$BUILD" ]; then
        fail "Target is already set once"
    fi

    if [[ ( "$1" =~ '.*#.*' ) || ( "${2:-}" = flake ) ]]; then
        BUILD="$1"
        TYPE=flake
    elif [  -r "$1/flake.nix" ]; then
        BUILD="$1#nixosConfigurations."$HOSTNAME".config.system.build.toplevel"
        TYPE=flake
    elif [ -r "$1/configuration.nix" ]; then
        BUILD="$1/configuration.nix"
        TYPE=legacy
    elif [ -r "$1/boot.json" ]; then
        TARGET=$1
        TYPE=built
    elif [ ! -e "$BUILD" ]; then
        fail "nothing is found $BUILD"
    elif [ -d "$BUILD" ]; then
        fail "not a valid directory. it should either contains a flake.nix to be a flake build, a configuration.nix to be a legacy build, or a boot.json to be a nixos top level directory"
    else
        return 1
    fi
}

while [[ $# -gt 0 ]]; do
    opt="$1"
    shift
    case "$opt" in
        --flake)
            set-target "$1" flake
            shift
            ;;
        -b|--boot)
            BOOT=y
            ;;
        -*|--*)
            fail "unrecognized option"
            ;;
        *)
            if set-target "$opt"; then
                :
            else
                fail "unrecognized argument: $opt"
            fi
            ;;
    esac
done

if [ -z "$BUILD" ]; then
    msg "Target not set. using $DEFAULT_TARGET"
    msg
    if set-target "$DEFAULT_TARGET"; then
        :
    else
        fail "weird...how am i getting this? $opt"
    fi
fi

if [[ ( ! -z "$BUILD" ) && (( $TYPE = flake ) ||  ( $TYPE = legacy ) ) ]]; then
    if [ $TYPE = flake ]; then
        TARGET=$(build-configuration-flake "$BUILD")
    else
        TARGET=$(build-configuration-legacy "$BUILD")
    fi
    RET=$?
    if [ $RET -ne 0 ]; then
        exit $RET
    fi
fi

if [ -z "$TARGET" ]; then
    fail "this is unreachable"
fi

LABEL="$(jq '."org.nixos.bootspec.v1".label' /nix/var/nix/profiles/system/boot.json -r)"

INITRD="$(jq '."org.nixos.bootspec.v1".initrd' /nix/var/nix/profiles/system/boot.json -r)"
KERNEL="$(jq '."org.nixos.bootspec.v1".kernel' /nix/var/nix/profiles/system/boot.json -r)"
INIT="$(jq '."org.nixos.bootspec.v1".init' /nix/var/nix/profiles/system/boot.json -r)"

CMDLINE="init=${INIT} $(jq '."org.nixos.bootspec.v1".kernelParams | join(" ")' /nix/var/nix/profiles/system/boot.json -r)"

msg "Loading:  $LABEL"
msg "Toplevel: $TARGET"
msg
msg "Kernel:   $KERNEL"
msg "Initrd:   $INITRD"
msg "Cmdline:  $CMDLINE"
msg

if [ $(id -u) -ne 0 ]; then
    msg "Warn: You are not running as root. kexec might fail. it is normal."
fi

run kexec -l --initrd=$INITRD --command-line="$CMDLINE" $KERNEL

if [ $BOOT == y ]; then
    sync
    if type systemctl &> /dev/null; then
        systemctl kexec
    else
        run kexec -e
    fi
fi
