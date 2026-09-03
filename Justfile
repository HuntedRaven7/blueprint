# No global dotenv: every variant's identity is inline in the `build` recipe
# case arms (and mirrored in `variant-env`). There is no primary env file.
export image_name := env_var_or_default("IMAGE_NAME", "blueprint")
export repo_organization := env_var_or_default("REPO_ORGANIZATION", "huntedraven7")
export image_desc := env_var_or_default("IMAGE_DESC", "")
export image_keywords := env_var_or_default("IMAGE_KEYWORDS", "")
export image_logo_url := env_var_or_default("IMAGE_LOGO_URL", "")
export default_tag := env_var_or_default("DEFAULT_TAG", "latest")
export bib_image := env_var_or_default("BIB_IMAGE", "quay.io/centos-bootc/bootc-image-builder:latest")

alias build-vm := build-qcow2
alias rebuild-vm := rebuild-qcow2
alias run-vm := run-vm-qcow2

[private]
default:
    @just --list

# Check Just Syntax
[group('Just')]
check:
    #!/usr/bin/env bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt --check -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile

# Fix Just Syntax
[group('Just')]
fix:
    #!/usr/bin/env bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt -f Justfile || { exit 1; }

# Clean Repo
[group('Utility')]
clean:
    #!/usr/bin/env bash
    set -eoux pipefail
    touch _build
    find *_build* -exec rm -rf {} \;
    rm -f previous.manifest.json
    rm -f changelog.md
    rm -f output.env
    rm -rf output/

# Sudo Clean Repo
[group('Utility')]
[private]
sudo-clean:
    just sudoif just clean

# sudoif bash function
[group('Utility')]
[private]
sudoif command *args:
    #!/usr/bin/env bash
    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" && -n "${SSH_ASKPASS:-}" ]] && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
            sudo --askpass "$@" || exit 1
        elif [[ "$(command -v sudo)" ]]; then
            sudo "$@" || exit 1
        else
            exit 1
        fi
    }
    sudoif {{ command }} {{ args }}

# This Justfile recipe builds a container image using Podman.
#
# Arguments:
#   $target_image - The tag you want to apply to the image (default: $image_name).
#   $tag - The tag for the image (default: $default_tag).
#
# The script constructs the version string using the tag and the current date.
# If the git working directory is clean, it also includes the short SHA of the current HEAD.
#
# just build $target_image $tag
#
# Example usage:
#   just build myimage mytag
#
# This will build an image 'myimage:mytag'
#

[private]
_ensure-yq:
    #!/usr/bin/env bash
    if ! command -v yq &> /dev/null && ! /home/linuxbrew/.linuxbrew/bin/yq --version &> /dev/null; then
        echo "Missing requirement: 'yq' is not installed."
        echo "Please install yq (e.g. 'brew install yq')"
        exit 1
    fi

# Build the image using the specified parameters
build $target_image="" $tag="" $dx="0" $kernel_pin="" $gnome_version="50" $major_version="10": _ensure-yq
    #!/usr/bin/env bash

    set -euo pipefail
    export PATH="/home/linuxbrew/.linuxbrew/bin:${PATH}"

    PRIMARY_STEM="blueprint"
    if [[ -z "${target_image}" ]]; then
        target_image="${PRIMARY_STEM}"
    fi

    # All variant identity is inline here; there are no per-variant env files.
    case "${target_image}" in
        arch*)
            IMAGE_NAME="arch-bootc"
            DEFAULT_TAG="testing"
            IMAGE_DESC="Arch Linux Bootc Image"
            IMAGE_KEYWORDS="bootc,oci,linux,arch"
            IMAGE_LOGO_URL="https://avatars.githubusercontent.com/u/120078124?s=200&v=4"
            REPO_ORGANIZATION="huntedraven7"
            BIB_IMAGE="quay.io/centos-bootc/bootc-image-builder:latest"
            ;;
        debian*)
            IMAGE_NAME="debian-bootc"
            DEFAULT_TAG="testing"
            IMAGE_DESC="Debian Trixie Bootc Image"
            IMAGE_KEYWORDS="bootc,oci,linux,debian,trixie"
            IMAGE_LOGO_URL="https://avatars.githubusercontent.com/u/120078124?s=200&v=4"
            REPO_ORGANIZATION="huntedraven7"
            BIB_IMAGE="quay.io/centos-bootc/bootc-image-builder:latest"
            ;;
        opensuse*)
            IMAGE_NAME="opensuse-bootc"
            DEFAULT_TAG="testing"
            IMAGE_DESC="OpenSUSE Tumbleweed Bootc Image"
            IMAGE_KEYWORDS="bootc,oci,linux,opensuse,tumbleweed"
            IMAGE_LOGO_URL="https://avatars.githubusercontent.com/u/120078124?s=200&v=4"
            REPO_ORGANIZATION="huntedraven7"
            BIB_IMAGE="quay.io/centos-bootc/bootc-image-builder:latest"
            ;;
        gentoo*)
            IMAGE_NAME="blueprint"
            DEFAULT_TAG="gentoo"
            IMAGE_DESC="Gentoo Linux Bootc Image"
            IMAGE_KEYWORDS="bootc,oci,linux,gentoo"
            IMAGE_LOGO_URL="https://avatars.githubusercontent.com/u/120078124?s=200&v=4"
            REPO_ORGANIZATION="huntedraven7"
            BIB_IMAGE="quay.io/centos-bootc/bootc-image-builder:latest"
            ;;
        nixos*)
            IMAGE_NAME="nixos-bootc"
            DEFAULT_TAG="testing"
            IMAGE_DESC="NixOS Bootc Base Image"
            IMAGE_KEYWORDS="bootc,oci,linux,nixos"
            IMAGE_LOGO_URL="https://avatars.githubusercontent.com/u/120078124?s=200&v=4"
            REPO_ORGANIZATION="huntedraven7"
            BIB_IMAGE="quay.io/centos-bootc/bootc-image-builder:latest"
            ;;
        ubuntu*)
            IMAGE_NAME="ubuntu-bootc"
            DEFAULT_TAG="testing"
            IMAGE_DESC="Ubuntu 26.04 Bootc Base Image"
            IMAGE_KEYWORDS="bootc,oci,linux,ubuntu"
            IMAGE_LOGO_URL="https://avatars.githubusercontent.com/u/120078124?s=200&v=4"
            REPO_ORGANIZATION="huntedraven7"
            BIB_IMAGE="quay.io/centos-bootc/bootc-image-builder:latest"
            ;;
        holo-amd*)
            IMAGE_NAME="blueprint"
            DEFAULT_TAG="holo-amd"
            IMAGE_DESC="Arch Linux Gaming Bootc Image (AMD)"
            IMAGE_KEYWORDS="bootc,oci,linux,arch,gaming,kde,steam,amd"
            IMAGE_LOGO_URL="https://avatars.githubusercontent.com/u/120078124?s=200&v=4"
            REPO_ORGANIZATION="huntedraven7"
            BIB_IMAGE="quay.io/centos-bootc/bootc-image-builder:latest"
            ;;
        holo-nvidia*)
            IMAGE_NAME="blueprint"
            DEFAULT_TAG="holo-nvidia"
            IMAGE_DESC="Arch Linux Gaming Bootc Image (NVIDIA)"
            IMAGE_KEYWORDS="bootc,oci,linux,arch,gaming,kde,steam,nvidia"
            IMAGE_LOGO_URL="https://avatars.githubusercontent.com/u/120078124?s=200&v=4"
            REPO_ORGANIZATION="huntedraven7"
            BIB_IMAGE="quay.io/centos-bootc/bootc-image-builder:latest"
            ;;
        robin*)
            IMAGE_NAME="robin"
            DEFAULT_TAG="testing"
            IMAGE_DESC="Arch Linux Niri + Quickshell Desktop"
            IMAGE_KEYWORDS="bootc,oci,linux,arch,niri,quickshell,wayland"
            IMAGE_LOGO_URL="https://avatars.githubusercontent.com/u/120078124?s=200&v=4"
            REPO_ORGANIZATION="huntedraven7"
            BIB_IMAGE="quay.io/centos-bootc/bootc-image-builder:latest"
            ;;
        *)
            echo "Unknown variant: '${target_image}'. No inline identity and no env file." >&2
            exit 1
            ;;
    esac

    # Every variant builds from the single root `Containerfile`; the per-variant
    # containerfiles/Containerfile.<variant> files no longer exist.
    CONTAINERFILE="Containerfile"

    TAG="${DEFAULT_TAG}"
    if [[ -n "${tag}" ]]; then
        TAG="${tag}"
    fi

    ver="${tag}.$(date +%Y%m%d)"

    BUILD_ARGS=()
    BUILD_ARGS+=("--build-arg" "MAJOR_VERSION={{ major_version }}")
    BUILD_ARGS+=("--build-arg" "IMAGE_NAME=${IMAGE_NAME}")
    BUILD_ARGS+=("--build-arg" "IMAGE_VENDOR=${REPO_ORGANIZATION}")
    BUILD_ARGS+=("--build-arg" "ENABLE_DX={{ dx }}")
    BUILD_ARGS+=("--build-arg" "GNOME_VERSION={{ gnome_version }}")

    # Unified root Containerfile args for the "other" images. These variants
    # build from the single root `Containerfile` and select their base image
    # and build/install scripts via build args.
    if [[ "${CONTAINERFILE}" == "Containerfile" ]]; then
        case "${target_image}" in
            arch)
                _base="archlinux:latest"; _sys="arch"; _b="builder-arch.sh"; _s="build-arch.sh" ;;
            debian)
                _base="docker.io/library/debian:testing"; _sys="debian"; _b="builder-debian.sh"; _s="build-debian.sh" ;;
            ubuntu)
                _base="ubuntu:26.04"; _sys="ubuntu"; _b="builder-ubuntu.sh"; _s="build-ubuntu.sh" ;;
            opensuse)
                _base="registry.opensuse.org/opensuse/tumbleweed:latest"; _sys="opensuse"; _b="builder-opensuse.sh"; _s="build-opensuse.sh" ;;
            gentoo)
                _base="gentoo/stage3:systemd"; _sys="gentoo"; _b="builder-gentoo.sh"; _s="build-gentoo.sh" ;;
            nixos)
                _base="nixos/nix:latest"; _sys="nixos"; _b="builder-nixos.sh"; _s="build-nixos.sh" ;;
            holo-amd)
                _base="arch-bootc:stable"; _sys="holo"; _b="holo/builder-holo-amd.sh"; _s="holo/build-amd.sh" ;;
            holo-nvidia)
                _base="arch-bootc:stable"; _sys="holo"; _b="holo/builder-holo-nvidia.sh"; _s="holo/build-nvidia.sh" ;;
            robin)
                _base="ghcr.io/huntedraven7/arch-bootc:testing"; _sys="robin"; _b="builder-robin.sh"; _s="build-robin.sh" ;;
        esac
        BUILD_ARGS+=("--build-arg" "VARIANT=${_sys}")
        BUILD_ARGS+=("--build-arg" "BASE_IMAGE=${_base}")
        BUILD_ARGS+=("--build-arg" "BUILDER_SCRIPT=${_b}")
        BUILD_ARGS+=("--build-arg" "BUILD_SCRIPT=${_s}")
        if [[ "${target_image}" == "nixos" ]]; then
            BUILD_ARGS+=("--build-arg" "LINT=0")
        fi
    fi

    if [[ -z "$(git status -s)" ]]; then
        BUILD_ARGS+=("--build-arg" "SHA_HEAD_SHORT=$(git rev-parse --short HEAD)")
    fi

    LABELS=()
    if [[ -z "$(git status -s)" ]]; then
        GIT_SHA=$(git rev-parse --short HEAD)
        LABELS+=("--label" "io.artifacthub.package.readme-url=https://raw.githubusercontent.com/${REPO_ORGANIZATION}/${IMAGE_NAME}/${GIT_SHA}/README.md")
        LABELS+=("--label" "org.opencontainers.image.documentation=https://raw.githubusercontent.com/${REPO_ORGANIZATION}/${IMAGE_NAME}/${GIT_SHA}/README.md")
        LABELS+=("--label" "org.opencontainers.image.source=https://github.com/${REPO_ORGANIZATION}/${IMAGE_NAME}/blob/${GIT_SHA}/${CONTAINERFILE}")
        LABELS+=("--label" "org.opencontainers.image.url=https://github.com/${REPO_ORGANIZATION}/${IMAGE_NAME}/tree/${GIT_SHA}")
        LABELS+=("--label" "org.opencontainers.image.version=${DEFAULT_TAG}.$(date +%Y%m%d)-${GIT_SHA}")
    fi
    LABELS+=("--label" "io.artifacthub.package.deprecated=false")
    LABELS+=("--label" "io.artifacthub.package.keywords=${IMAGE_KEYWORDS}")
    LABELS+=("--label" "io.artifacthub.package.license=Apache-2.0")
    LABELS+=("--label" "io.artifacthub.package.logo-url=${IMAGE_LOGO_URL}")
    LABELS+=("--label" "io.artifacthub.package.prerelease=false")
    LABELS+=("--label" "org.opencontainers.image.created=$(date -u +%Y\-%m\-%d\T%H\:%M\:%S\Z)")
    LABELS+=("--label" "org.opencontainers.image.description=${IMAGE_DESC}")
    LABELS+=("--label" "org.opencontainers.image.title=${IMAGE_NAME}")
    LABELS+=("--label" "org.opencontainers.image.vendor=${REPO_ORGANIZATION}")

    PODMAN_BUILD_ARGS=("${BUILD_ARGS[@]}" "${LABELS[@]}" "--pull=newer" "--tag" "${IMAGE_NAME}:${TAG}" "--file" "${CONTAINERFILE}")

    podman build "${PODMAN_BUILD_ARGS[@]}" .

# Build the fsdk image using BuildStream (pure FSDK composition, no apt)
[group('Build')]
build-fsdk $tag="fsdk":
    #!/usr/bin/env bash
    set -euo pipefail
    cd buildstream && just build

# Build images from containerfiles/ subdirectories
[group('Build')]
build-containerfile $target_image="" $tag="stable":
    #!/usr/bin/env bash
    set -euo pipefail
    CONTAINERFILE_DIR="containerfiles/${target_image}"
    if [[ ! -d "${CONTAINERFILE_DIR}" ]]; then
        echo "No containerfile directory found for ${target_image}" >&2
        exit 1
    fi
    cd "${CONTAINERFILE_DIR}"
    CONTAINERFILE="Containerfile"
    if [[ ! -f "${CONTAINERFILE}" ]]; then
        CONTAINERFILE="Containerfile.${target_image}"
    fi
    if [[ ! -f "${CONTAINERFILE}" ]]; then
        echo "No Containerfile found in ${CONTAINERFILE_DIR}" >&2
        exit 1
    fi
    podman build \
        --build-arg "IMAGE_NAME=${target_image}" \
        --build-arg "UBLUE_IMAGE_TAG=${tag}" \
        --pull=newer \
        --no-cache \
        --tag "${target_image}:${tag}" \
        --file "${CONTAINERFILE}" \
        .

# Build all images in the repo
[group('Build')]
build-all:
    #!/usr/bin/env bash
    set -euo pipefail
    just build debian
    just build ubuntu
    just build nixos
    just build holo-amd
    just build holo-nvidia
    just build-fsdk
    just build-containerfile robin
    just build-containerfile server
    just build-containerfile aira
    just build-containerfile ai

# Build an image then rechunk it for smaller bootc delta updates
build-rechunked $target_image=image_name $tag=default_tag: && (rechunk target_image tag)

# Split the image for smaller updates (New)!
rechunk $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash

    set -xeuo pipefail

    # TODO: pin chunkah image to hash once mature enough
    # You may run into space issues on github runners as we are making a
    # complete copy of the image, which likely has no shared layers, unless your
    # base image is also using chunkah
    CHUNKAH_CONFIG_FILE="$(mktemp)"

    # You may omit the current directory here if you are confident that you
    # won't run out of space on /tmp for your image
    CHUNKAH_OUTPUT_DIR="$(mktemp -d ./"${target_image}"_chunkah_XXXXXX)"

    trap 'rm -f "${CHUNKAH_CONFIG_FILE}"; rm -rf "${CHUNKAH_OUTPUT_DIR}"' EXIT
    podman inspect "${target_image}:${tag}" > "${CHUNKAH_CONFIG_FILE}"

    podman run --rm \
      --mount=type=image,src="${target_image}:${tag}",target=/chunkah \
      -v "${CHUNKAH_CONFIG_FILE}:/chunkah-config.json:ro,Z" \
      -v "${CHUNKAH_OUTPUT_DIR}:/run/out:Z" \
      quay.io/coreos/chunkah:latest \
      build \
      --verbose \
      --compressed \
      --max-layers 128 \
      --prune /sysroot/ \
      --label ostree.commit- --label ostree.final-diffid- \
      --config /chunkah-config.json \
      --output oci:/run/out/chunked

    CHUNKED_IMAGE="$(podman pull "oci:${CHUNKAH_OUTPUT_DIR}/chunked")"
    podman tag "${CHUNKED_IMAGE}" "${target_image}:${tag}"

# Split the image for smaller updates (Classical)!
ostree-rechunk $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash

    set -xeuo pipefail

    # TODO: This is the only blocker for rootless CI
    # https://github.com/coreos/rpm-ostree/issues/5346
    if [[ ! "${UID}" -eq "0" ]]; then
      echo "This needs to run as root."
      exit 1
    fi

    # Use the already-built local image to avoid pulling from a remote registry
    RPM_OSTREE_CHUNKER_IMAGE="localhost/${target_image}:${tag}"

    podman run --rm \
      --pull=never \
      --privileged \
      -v "/var/lib/containers:/var/lib/containers" \
      --entrypoint /usr/bin/rpm-ostree \
      "${RPM_OSTREE_CHUNKER_IMAGE}" \
      compose build-chunked-oci \
      --max-layers 127 \
      --format-version=2 \
      --bootc \
      --from "localhost/${target_image}:${tag}" \
      --output containers-storage:"localhost/${target_image}:${tag}"

# Generate Default Tag
[group('Utility')]
generate-default-tag $tag=default_tag:
    #!/usr/bin/env bash
    set -eoux pipefail

    echo "${tag}"

# Generate Tags
[group('Utility')]
generate-build-tags $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -eoux pipefail

    # All alias tags are prefixed with the variant tag so variants sharing an
    # image name (e.g. blueprint:latest, blueprint:holo-amd) never overwrite each other
    DATE=$(date +%Y%m%d)
    BUILD_TAGS=()
    if [[ -z "$(git status -s)" ]]; then
        GIT_SHA=$(git rev-parse --short HEAD)
        BUILD_TAGS+=("${tag}-${GIT_SHA}")
        BUILD_TAGS+=("${tag}-${DATE}-${GIT_SHA}")
    fi

    BUILD_TAGS+=("${tag}-${DATE}")
    BUILD_TAGS+=("${tag}")

    echo "${BUILD_TAGS[@]}"

# Tag Images
[group('Utility')]
tag-images $target_image=image_name $tag=default_tag tags="":
    #!/usr/bin/env bash
    set -eoux pipefail

    # Get Image, and untag
    IMAGE=$(podman inspect ${target_image}:${tag} | jq -r .[].Id)
    podman untag ${IMAGE}

    # Tag Image
    for tag in {{ tags }}; do
        podman tag $IMAGE "${target_image}:${tag}"
    done

    # Show Images
    podman images

# Image Name
[group('Utility')]
[private]
image_name $target_image=image_name:
    #!/usr/bin/env bash
    set -eoux pipefail

    echo "${image_name}"

# List all variant keys defined in this repo (env files with a matching containerfiles/Containerfile.<name>)
[group('Utility')]
list-images:
    #!/usr/bin/env bash
    set -eoux pipefail

    IMAGES=()
    for env in images/*.env; do
        [[ -f "${env}" ]] || continue
        stem="${env#images/}"
        stem="${stem%.env}"
        if [[ -f "containerfiles/Containerfile.${stem}" ]] || [[ -f "buildstream/Containerfile.${stem}" ]]; then
            case "${stem}" in
                arch|arch-bootc|debian-bootc|holo-amd|holo-nvidia|ai|debian|gentoo|opensuse|opensuse-bootc|ubuntu|nixos|fsdk) continue ;;
            esac
            IMAGES+=("${stem}")
        fi
    done

    printf '%s\n' "${IMAGES[@]}"

# Print IMAGE_NAME and DEFAULT_TAG for a variant key
[group('Utility')]
[private]
variant-env $target_image=image_name:
    #!/usr/bin/env bash
    set -eoux pipefail

    # Mirror the inline identity defined in the `build` recipe case arms.
    case "${target_image}" in
        arch*)        IMAGE_NAME="arch-bootc";   DEFAULT_TAG="testing" ;;
        debian*)      IMAGE_NAME="debian-bootc"; DEFAULT_TAG="testing" ;;
        opensuse*)    IMAGE_NAME="opensuse-bootc"; DEFAULT_TAG="testing" ;;
        gentoo*)      IMAGE_NAME="blueprint";    DEFAULT_TAG="gentoo" ;;
        nixos*)       IMAGE_NAME="nixos-bootc";  DEFAULT_TAG="testing" ;;
        ubuntu*)      IMAGE_NAME="ubuntu-bootc"; DEFAULT_TAG="testing" ;;
        holo-amd*)    IMAGE_NAME="blueprint";    DEFAULT_TAG="holo-amd" ;;
        holo-nvidia*) IMAGE_NAME="blueprint";    DEFAULT_TAG="holo-nvidia" ;;
        robin*)       IMAGE_NAME="robin";        DEFAULT_TAG="testing" ;;
        fsdk*)        IMAGE_NAME="blueprint";    DEFAULT_TAG="fsdk" ;;
        server*)      IMAGE_NAME="server";       DEFAULT_TAG="testing" ;;
        aira*)        IMAGE_NAME="aira";         DEFAULT_TAG="testing" ;;
        ai*)          IMAGE_NAME="ai";           DEFAULT_TAG="testing" ;;
        *)
            echo "Unknown variant: '${target_image}'" >&2
            exit 1
            ;;
    esac

    echo "IMAGE_NAME=${IMAGE_NAME}"
    echo "DEFAULT_TAG=${DEFAULT_TAG}"

# Command: _rootful_load_image
# Description: This script checks if the current user is root or running under sudo. If not, it attempts to resolve the image tag using podman inspect.
#              If the image is found, it loads it into rootful podman. If the image is not found, it pulls it from the repository.
#
# Parameters:
#   $target_image - The name of the target image to be loaded or pulled.
#   $tag - The tag of the target image to be loaded or pulled. Default is 'default_tag'.
#
# Example usage:
#   _rootful_load_image my_image latest
#
# Steps:
# 1. Check if the script is already running as root or under sudo.
# 2. Check if target image is in the non-root podman container storage)
# 3. If the image is found, load it into rootful podman using podman scp.
# 4. If the image is not found, pull it from the remote repository into reootful podman.

_rootful_load_image $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -eoux pipefail

    # Check if already running as root or under sudo
    if [[ -n "${SUDO_USER:-}" || "${UID}" -eq "0" ]]; then
        echo "Already root or running under sudo, no need to load image from user podman."
        exit 0
    fi

    # Try to resolve the image tag using podman inspect
    set +e
    resolved_tag=$(podman inspect -t image "${target_image}:${tag}" | jq -r '.[].RepoTags.[0]')
    return_code=$?
    set -e

    USER_IMG_ID=$(podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")

    if [[ $return_code -eq 0 ]]; then
        # If the image is found, load it into rootful podman
        ID=$(just sudoif podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")
        if [[ "$ID" != "$USER_IMG_ID" ]]; then
            # If the image ID is not found or different from user, copy the image from user podman to root podman
            COPYTMP=$(mktemp -p "${PWD}" -d -t _build_podman_scp.XXXXXXXXXX)
            just sudoif TMPDIR=${COPYTMP} podman image scp ${UID}@localhost::"${target_image}:${tag}" root@localhost::"${target_image}:${tag}"
            rm -rf "${COPYTMP}"
        fi
    else
        # If the image is not found, pull it from the repository
        just sudoif podman pull "${target_image}:${tag}"
    fi

# Build a bootc bootable image using Bootc Image Builder (BIB)
# Converts a container image to a bootable image
# Parameters:
#   target_image: The name of the image to build (ex. localhost/fedora)
#   tag: The tag of the image to build (ex. latest)
#   type: The type of image to build (ex. qcow2, raw, iso)
#   config: The configuration file to use for the build (default: disk_config/disk.toml)

# Example: just _rebuild-bib localhost/fedora latest qcow2 disk_config/disk.toml
_build-bib $target_image $tag $type $config: (_rootful_load_image target_image tag)
    #!/usr/bin/env bash
    set -euo pipefail

    args="--type ${type} "
    args+="--use-librepo=True "
    args+="--rootfs=btrfs"

    BUILDTMP=$(mktemp -p "${PWD}" -d -t _build-bib.XXXXXXXXXX)

    sudo podman run \
      --rm \
      -it \
      --privileged \
      --pull=newer \
      --net=host \
      --security-opt label=type:unconfined_t \
      -v $(pwd)/${config}:/config.toml:ro \
      -v $BUILDTMP:/output \
      -v /var/lib/containers/storage:/var/lib/containers/storage \
      "${bib_image}" \
      ${args} \
      "${target_image}:${tag}"

    mkdir -p output
    sudo mv -f $BUILDTMP/* output/
    sudo rmdir $BUILDTMP
    sudo chown -R $USER:$USER output/

# Podman builds the image from the Containerfile and creates a bootable image
# Parameters:
#   target_image: The name of the image to build (ex. localhost/fedora)
#   tag: The tag of the image to build (ex. latest)
#   type: The type of image to build (ex. qcow2, raw, iso)
#   config: The configuration file to use for the build (deafult: disk_config/disk.toml)

# Example: just _rebuild-bib localhost/fedora latest qcow2 disk_config/disk.toml
_rebuild-bib $target_image $tag $type $config: (build target_image tag) && (_build-bib target_image tag type config)

# Build a QCOW2 virtual machine image
[group('Build Virtal Machine Image')]
build-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "qcow2" "disk_config/disk.toml")

# Build a RAW virtual machine image
[group('Build Virtal Machine Image')]
build-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "raw" "disk_config/disk.toml")

# Build an ISO virtual machine image
[group('Build Virtal Machine Image')]
build-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "iso" "disk_config/iso.toml")

# Build an installer ISO using bootc-installer
[group('Build Virtal Machine Image')]
build-iso-kde: && (_rebuild-bib "ghcr.io/huntedraven7/blueprint" "robin" "iso" "disk_config/iso-kde.toml")

# Build a server installer ISO using BIB (Anaconda-based)
[group('Build Virtal Machine Image')]
build-server-iso: (build-containerfile "server") && (_build-bib "ghcr.io/huntedraven7/blueprint" "server" "iso" "disk_config/iso-server.toml")

# Build the ncurses server installer ISO (uses lorax/livemedia-creator)
[group('Build Virtal Machine Image')]
build-installer-iso:
    #!/usr/bin/env bash
    set -euo pipefail
    just sudoif bash installer/build-installer-iso.sh

# Rebuild a QCOW2 virtual machine image
[group('Build Virtal Machine Image')]
rebuild-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "qcow2" "disk_config/disk.toml")

# Rebuild a RAW virtual machine image
[group('Build Virtal Machine Image')]
rebuild-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "raw" "disk_config/disk.toml")

# Rebuild an ISO virtual machine image
[group('Build Virtal Machine Image')]
rebuild-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "iso" "disk_config/iso.toml")

# Run a virtual machine with the specified image type and configuration
_run-vm $target_image $tag $type $config:
    #!/usr/bin/env bash
    set -eoux pipefail

    # Determine the image file based on the type
    image_file="output/${type}/disk.${type}"
    if [[ $type == iso ]]; then
        image_file="output/bootiso/install.iso"
    fi

    # Build the image if it does not exist
    if [[ ! -f "${image_file}" ]]; then
        just "build-${type}" "$target_image" "$tag"
    fi

    # Determine an available port to use
    port=8006
    while grep -q :${port} <<< $(ss -tunalp); do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"

    # Set up the arguments for running the VM
    run_args=()
    run_args+=(--rm --privileged)
    run_args+=(--pull=newer)
    run_args+=(--publish "127.0.0.1:${port}:8006")
    run_args+=(--env "CPU_CORES=4")
    run_args+=(--env "RAM_SIZE=8G")
    run_args+=(--env "DISK_SIZE=64G")
    run_args+=(--env "TPM=Y")
    run_args+=(--env "GPU=Y")
    run_args+=(--device=/dev/kvm)
    run_args+=(--volume "${PWD}/${image_file}":"/boot.${type}")
    run_args+=(docker.io/qemux/qemu)

    # Run the VM and open the browser to connect
    (sleep 30 && xdg-open http://localhost:"$port") &
    podman run "${run_args[@]}"

# Run a virtual machine from a QCOW2 image
[group('Run Virtal Machine')]
run-vm-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "qcow2" "disk_config/disk.toml")

# Run a virtual machine from a RAW image
[group('Run Virtal Machine')]
run-vm-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "raw" "disk_config/disk.toml")

# Run a virtual machine from an ISO
[group('Run Virtal Machine')]
run-vm-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "iso" "disk_config/iso.toml")

# Run the server installer ISO in a VM
[group('Run Virtal Machine')]
run-server-iso: && (_run-vm "localhost/blueprint" "server" "iso" "disk_config/iso-server.toml")

# Run the ncurses installer ISO in a VM
[group('Run Virtal Machine')]
run-installer-iso:
    #!/usr/bin/env bash
    set -eoux pipefail

    ISO_FILE="output/installer-iso/blueprint-server-installer-$(date +%Y%m%d).iso"
    if [[ ! -f "$ISO_FILE" ]]; then
        # Try to find any installer ISO
        ISO_FILE=$(find output/installer-iso -name "*.iso" -type f 2>/dev/null | head -1)
    fi

    if [[ -z "$ISO_FILE" ]] || [[ ! -f "$ISO_FILE" ]]; then
        echo "No installer ISO found. Building first..."
        just build-installer-iso
        ISO_FILE="output/installer-iso/blueprint-server-installer-$(date +%Y%m%d).iso"
    fi

    port=8006
    while grep -q :${port} <<< $(ss -tunalp); do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"

    run_args=()
    run_args+=(--rm --privileged)
    run_args+=(--pull=newer)
    run_args+=(--publish "127.0.0.1:${port}:8006")
    run_args+=(--env "CPU_CORES=4")
    run_args+=(--env "RAM_SIZE=8G")
    run_args+=(--env "DISK_SIZE=64G")
    run_args+=(--env "TPM=Y")
    run_args+=(--env "GPU=Y")
    run_args+=(--device=/dev/kvm)
    run_args+=(--volume "${PWD}/${ISO_FILE}:/boot.iso")
    run_args+=(docker.io/qemux/qemu)

    (sleep 30 && xdg-open http://localhost:"$port") &
    podman run "${run_args[@]}"

# Run a virtual machine using systemd-vmspawn
[group('Run Virtal Machine')]
spawn-vm rebuild="0" type="qcow2" ram="6G":
    #!/usr/bin/env bash

    set -euo pipefail

    [ "{{ rebuild }}" -eq 1 ] && echo "Rebuilding the ISO" && just build-vm {{ rebuild }} {{ type }}

    systemd-vmspawn \
      -M "bootc-image" \
      --console=gui \
      --cpus=2 \
      --ram=$(echo {{ ram }}| numfmt --from=iec) \
      --network-user-mode \
      --vsock=false --pass-ssh-key=false \
      -i ./output/**/*.{{ type }}

# Runs shell check on all Bash scripts
lint:
    #!/usr/bin/env bash
    set -eoux pipefail
    # Check if shellcheck is installed
    if ! command -v shellcheck &> /dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    # Run shellcheck on all Bash scripts
    find . -iname "*.sh" -type f -exec shellcheck "{}" ';'

# Runs shfmt on all Bash scripts
format:
    #!/usr/bin/env bash
    set -eoux pipefail
    # Check if shfmt is installed
    if ! command -v shfmt &> /dev/null; then
        echo "shfmt could not be found. Please install it."
        exit 1
    fi
    # Run shfmt on all Bash scripts
    find . -iname "*.sh" -type f -exec shfmt --write "{}" ';'
