#!/bin/bash
#
# Create an application shortcut (desktop launcher) for DaVinci Resolve.
#
# Automates the "创建快捷方式" steps from README.md:
#   1. Copy DV_Resolve.png into ~/.local/share/icons/
#   2. Point the Exec line at the real resolve.sh path
#   3. Install resolve.desktop into ~/.local/share/applications/

REPO_DIR="$(dirname "$(realpath -s "$0")")"

# Reuse the podman/docker detection from env-set.sh (sets CONTAINER_ENGINE).
# Use POSIX "." instead of "source" so the script also works under sh/dash.
. "${REPO_DIR}/env-set.sh"

# resolve.sh defaults RESOLVE_TAG to "latest"; match it here.
RESOLVE_TAG="${RESOLVE_TAG:-latest}"

ICON_SRC="/opt/resolve/graphics/DV_Resolve.png"
ICON_DIR="${HOME}/.local/share/icons"
ICON_DST="${ICON_DIR}/DV_Resolve.png"
APPS_DIR="${HOME}/.local/share/applications"
DESKTOP_DST="${APPS_DIR}/resolve.desktop"

mkdir -p "${ICON_DIR}" "${APPS_DIR}"

# --- 1. Copy the icon out of the container image ----------------------------
# The runtime container is ephemeral (--rm), so extract the icon from a
# throwaway container created from the image instead.
TMP_CONTAINER="resolve_icon_copy"

# Drop any stale temp container left over from a previously interrupted run.
if ${CONTAINER_ENGINE} inspect "${TMP_CONTAINER}" >/dev/null 2>&1; then
    ${CONTAINER_ENGINE} rm -f "${TMP_CONTAINER}" >/dev/null
fi

if ! ${CONTAINER_ENGINE} create --name "${TMP_CONTAINER}" "resolve:${RESOLVE_TAG}" >/dev/null; then
    echo "Failed to create a temporary container from 'resolve:${RESOLVE_TAG}'." >&2
    echo "Build the image first (./build.sh)." >&2
    exit 1
fi

cleanup() {
    ${CONTAINER_ENGINE} rm -f "${TMP_CONTAINER}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

if ! ${CONTAINER_ENGINE} cp "${TMP_CONTAINER}:${ICON_SRC}" "${ICON_DST}"; then
    echo "Failed to copy '${ICON_SRC}' out of the image." >&2
    exit 1
fi

# --- Create a (default empty) resolve.rc for the launcher's RESOLVE_RC_PATH ----
RESOLVE_RC="${REPO_DIR}/resolve.rc"

if [ ! -f "${RESOLVE_RC}" ]; then
    cat > "${RESOLVE_RC}" <<'EOF'
#!/bin/bash
EOF
    chmod +x "${RESOLVE_RC}" 2>/dev/null || true
fi

# --- 2 & 3. Generate and install the .desktop file --------------------------
cat > "${DESKTOP_DST}" <<EOF
[Desktop Entry]
Name=DaVinci Resolve
Icon=DV_Resolve.png
Exec=bash -c "cd ${REPO_DIR} && RESOLVE_RC_PATH=${RESOLVE_RC} ./resolve.sh"
Type=Application
Terminal=false
StartupNotify=true
EOF

chmod +x "${DESKTOP_DST}" 2>/dev/null || true

echo "Done."
echo "  Icon     : ${ICON_DST}"
echo "  Launcher : ${DESKTOP_DST}"
echo "  Mounts   : ${RESOLVE_RC}"
echo "  Exec     : bash -c \"cd ${REPO_DIR} && RESOLVE_RC_PATH=${RESOLVE_RC} ./resolve.sh\""