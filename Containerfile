# Unified Containerfile for the "other" blueprint images:
#   arch, debian, ubuntu, opensuse, gentoo, nixos, holo-amd, holo-nvidia, robin
#
# robin, aira, server, crmy, ai keep their own containerfiles/Containerfile.<variant>.
#
# Select the target and base with build args (the Justfile `build` recipe does
# this for you):
#   --build-arg VARIANT=<name>          system_files dir + default script stem
#   --build-arg BASE_IMAGE=<image>      FROM for the builder + system stages
#   --build-arg BUILDER_SCRIPT=<path>   script run in the builder stage
#   --build-arg BUILD_SCRIPT=<path>     script run in the system stage
#   --build-arg LINT=<0|1>              run `bootc container lint` (default 1)
# Plus the shared args the build passes: IMAGE_NAME, IMAGE_VENDOR,
# MAJOR_VERSION, ENABLE_DX, GNOME_VERSION, SHA_HEAD_SHORT.

ARG VARIANT="arch"
ARG BASE_IMAGE="archlinux:latest"
ARG BUILDER_SCRIPT="builder-${VARIANT}.sh"
ARG BUILD_SCRIPT="build-${VARIANT}.sh"
ARG LINT="1"

ARG IMAGE_NAME="blueprint"
ARG IMAGE_VENDOR="huntedraven7"
ARG MAJOR_VERSION="10"
ARG ENABLE_DX="0"
ARG GNOME_VERSION="50"
ARG SHA_HEAD_SHORT="deadbeef"

FROM scratch AS ctx
# Re-declare args used after FROM (pre-FROM ARGs are out of scope in build steps).
ARG VARIANT
COPY build_files /
COPY system_files/global /system_files/global
COPY system_files/${VARIANT} /system_files/${VARIANT}

# Builder stage: compile bootc (and friends) from source for the distro.
# For "derived" images (holo-*) this is a no-op; the real work happens in the
# system stage via BUILD_SCRIPT.
FROM ${BASE_IMAGE} AS builder
ARG BUILDER_SCRIPT
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/base/${BUILDER_SCRIPT}

# System stage: install the actual system packages / finalize the image.
FROM ${BASE_IMAGE} AS system
ARG BUILD_SCRIPT
ARG LINT
COPY --from=builder /output /
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/base/${BUILD_SCRIPT}
LABEL containers.bootc 1
RUN if [ "${LINT}" != "0" ]; then bootc container lint; fi
