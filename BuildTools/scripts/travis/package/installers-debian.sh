#!/bin/bash
SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
. "${SCRIPT_DIR}/utils.sh"

function build_installer () {
    DIRNAME=$(echo "${RELEASE_FILE_NAME}" | cut -d "_" -f 1)
	DEBNAME="duplicati_${RELEASE_VERSION}-1_all.deb"
    DATE_STAMP=$(LANG=C date -R)
    installer_dir="${DUPLICATI_ROOT}/BuildTools/Installer/debian/"

    unzip -q -d "${installer_dir}/${DIRNAME}" "$ZIPFILE"

    install_oem_files "${installer_dir}/" "${installer_dir}/${DIRNAME}"

    cp -R "${installer_dir}/debian" "${installer_dir}/${DIRNAME}"
    cp "${installer_dir}/bin-rules.sh" "${installer_dir}/${DIRNAME}/debian/rules"
    sed -e "s;%VERSION%;${RELEASE_VERSION};g" -e "s;%DATE%;$DATE_STAMP;g" "${installer_dir}/debian/changelog" > "${DUPLICATI_ROOT}/BuildTools/Installer/debian/${DIRNAME}/debian/changelog"

    touch "${installer_dir}/${DIRNAME}/releasenotes.txt"

    docker build -t "duplicati/debian-build:latest" - < "${installer_dir}/Dockerfile.build"

    # Weirdness with time not being synced in Docker instance
    sleep 5

    docker run --rm --workdir "/builddir/${DIRNAME}" --volume "${WORKING_DIR}/BuildTools/Installer/debian/":/builddir:rw "duplicati/debian-build:latest" dpkg-buildpackage

	mv "${installer_dir}/${DEBNAME}" "${UPDATE_TARGET}"
}

parse_options "$@"

travis_mark_begin "BUILDING DEBIAN PACKAGE"
build_installer
travis_mark_end "BUILDING DEBIAN PACKAGE"
