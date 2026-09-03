#!/bin/bash
set -ouex pipefail

# robin images derive from arch-bootc:testing and do all their work in the system
# stage via build-robin.sh. This builder-stage script is a no-op placeholder so
# the unified root Containerfile can drive robin uniformly.
true
