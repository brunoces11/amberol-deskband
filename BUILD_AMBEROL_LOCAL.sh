#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PATCH_FILE="$SCRIPT_DIR/AMBEROL_SHUFFLE_MPRIS.patch"
VERSION="2026.1"
ARCHIVE_SHA256="2112eebac5c7b0aab7243c428c794aecb136168c326648cfbbd8654ea2cc7631"
CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/amberol-deskband"
SOURCE_DIR="$CACHE_ROOT/source-$VERSION"
BUILD_DIR="$CACHE_ROOT/build-$VERSION"
PREFIX="$HOME/.local/lib/amberol-deskband"
CUSTOM_BIN="$PREFIX/bin/amberol"
DISABLED_BIN="$PREFIX/bin/amberol.stock-disabled"

export PATH="$HOME/.cargo/bin:$PATH"

print_backend() {
    AMBEROL_DESKBAND_PRINT_BACKEND=1 "$HOME/.local/bin/amberol"
}

case "${1:-build}" in
    --status)
        print_backend
        exit 0
        ;;
    --restore-stock)
        if [[ -x "$CUSTOM_BIN" ]]; then
            if [[ -e "$DISABLED_BIN" ]]; then
                echo "Preservado: já existe $DISABLED_BIN; não sobrescrevi esse arquivo." >&2
                exit 1
            fi
            mv -- "$CUSTOM_BIN" "$DISABLED_BIN"
        fi
        selected="$(print_backend)"
        if [[ "$selected" != "/usr/bin/amberol" ]]; then
            echo "Falha: o wrapper ainda seleciona $selected." >&2
            exit 1
        fi
        echo "OK: wrapper restaurado para /usr/bin/amberol."
        exit 0
        ;;
    build)
        ;;
    *)
        echo "Uso: $0 [--status|--restore-stock]" >&2
        exit 2
        ;;
esac

for tool in cargo meson ninja blueprint-compiler pkg-config curl tar patch sha256sum; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Dependência ausente: $tool. Consulte a seção Shuffle e repetição no README." >&2
        exit 1
    fi
done

for dependency in gtk4 libadwaita-1 gstreamer-1.0 gstreamer-audio-1.0 gstreamer-play-1.0 gstreamer-plugins-base-1.0 gstreamer-plugins-bad-1.0 gstreamer-bad-audio-1.0; do
    if ! pkg-config --exists "$dependency"; then
        echo "Dependência de compilação ausente no pkg-config: $dependency" >&2
        exit 1
    fi
done

if [[ -e "$SOURCE_DIR" ]]; then
    expected_marker="$ARCHIVE_SHA256 $(sha256sum "$PATCH_FILE" | cut -d' ' -f1)"
    if [[ ! -f "$SOURCE_DIR/.deskband-source-marker" ]] || [[ "$(cat "$SOURCE_DIR/.deskband-source-marker")" != "$expected_marker" ]]; then
        echo "A fonte em $SOURCE_DIR não corresponde ao patch esperado; preservada sem alterações." >&2
        exit 1
    fi
else
    mkdir -p "$CACHE_ROOT"
    work_dir="$(mktemp -d "$CACHE_ROOT/work.XXXXXX")"
    trap 'python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$work_dir"' EXIT
    archive="$work_dir/amberol-$VERSION.tar.gz"
    source_stage="$work_dir/source"
    curl --fail --location --proto '=https' --tlsv1.2 \
        "https://gitlab.gnome.org/World/amberol/-/archive/$VERSION/amberol-$VERSION.tar.gz" \
        --output "$archive"
    echo "$ARCHIVE_SHA256  $archive" | sha256sum --check --status || {
        echo "O arquivo oficial do Amberol não corresponde ao SHA-256 fixado." >&2
        exit 1
    }
    mkdir -p "$source_stage"
    tar --extract --gzip --strip-components=1 --file="$archive" --directory="$source_stage"
    patch --batch --forward --directory="$source_stage" --strip=1 --input="$PATCH_FILE"
    printf '%s\n' "$ARCHIVE_SHA256 $(sha256sum "$PATCH_FILE" | cut -d' ' -f1)" > "$source_stage/.deskband-source-marker"
    mv -- "$source_stage" "$SOURCE_DIR"
    test -f "$SOURCE_DIR/.deskband-source-marker"
    echo "VERIFICADO: fonte oficial extraída e patch MPRIS aplicado."
fi

if [[ -f "$BUILD_DIR/meson-private/coredata.dat" ]]; then
    meson setup --reconfigure "$BUILD_DIR" "$SOURCE_DIR" --prefix="$PREFIX" --buildtype=release
else
    meson setup "$BUILD_DIR" "$SOURCE_DIR" --prefix="$PREFIX" --buildtype=release
fi
meson compile --jobs 2 -C "$BUILD_DIR"
meson install -C "$BUILD_DIR"

if [[ ! -x "$CUSTOM_BIN" || ! -s "$PREFIX/share/amberol/amberol.gresource" || ! -s "$PREFIX/share/glib-2.0/schemas/io.bassi.Amberol.gschema.xml" ]]; then
    echo "Falha na validação da instalação local do Amberol." >&2
    exit 1
fi
selected="$(print_backend)"
if [[ "$selected" != "$CUSTOM_BIN" ]]; then
    echo "Falha: o wrapper seleciona $selected em vez do build local." >&2
    exit 1
fi
echo "VERIFICADO: Amberol $VERSION com Shuffle MPRIS instalado em $CUSTOM_BIN."
