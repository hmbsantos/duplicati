
# duplicati root is relative to the stage dirs
DUPLICATI_ROOT="$( cd "$(dirname "$0")" ; pwd -P )/../../../../"

function quit_on_error() {
  local parent_lineno="$1"
  local message="$2"
  local code="${3:-1}"
  if [[ -n "$message" ]] ; then
    echo "Error in $0 line ${parent_lineno}: ${message}; exiting with status ${code}"
  else
    echo "Error in $0 line ${parent_lineno}; exiting with status ${code}"
  fi
  exit "${code}"
}

set -eE
trap 'quit_on_error $LINENO' ERR

function travis_mark_begin () {
    echo "travis_fold:start:$1"
    echo "+ START $1"
}

function travis_mark_end () {
    echo "travis_fold:end:$1"
    echo "+ DONE $1"
}

function load_mono () {
    echo "travis_fold:start:pull_mono"
    image="$CACHE_DIR/mono.tar"
    if [[ -f "$image" ]] && $CACHE_MONO; then
      echo "loading previously cached docker image"
      docker load <  "$image"
    else
      docker pull mono
      if $CACHE_MONO; then
        docker save mono > "$CACHE_DIR"/mono.tar
      fi
    fi
    echo "travis_fold:end:pull_mono"
}

function test_in_docker() {
    mono_docker "./BuildTools/scripts/travis/unittest/install.sh;./BuildTools/scripts/travis/unittest/test.sh $TEST_CATEGORIES $TEST_DATA"
}

function deploy_in_docker() {
    mono_docker "./BuildTools/scripts/travis/deploy/install.sh;./BuildTools/scripts/travis/deploy/package.sh $FORWARD_OPTS"
}

function build_in_docker () {
    mono_docker "./BuildTools/scripts/travis/build/install.sh $FORWARD_OPTS;./BuildTools/scripts/travis/build/build.sh $FORWARD_OPTS"
}

function setup_cache () {
  sudo rsync -a --delete "$REPO_DIR"/ "$CACHE_DIR"
  WORKING_DIR="$CACHE_DIR"
}

function setup_copy_cache () {
  COPY_CACHE="${CACHE_DIR}/../.copy_cache"
  sudo rsync -a --delete "$CACHE_DIR"/ "$COPY_CACHE"
  WORKING_DIR="$COPY_CACHE"
}

function restore_build_to_cache () {
  . "${SCRIPT_DIR}/../build/wrapper.sh" --redirect
}

function mono_docker () {
  docker run -v "${WORKING_DIR}:/duplicati" mono /bin/bash -c "cd /duplicati;$1"
}

function parse_options () {
  QUIET=false
  FORWARD_OPTS=""
  CACHE_MONO=false
  RELEASE_VERSION="2.0.4.$(cat "$DUPLICATI_ROOT"/Updates/build_version.txt)"
  RELEASE_TYPE="canary"
  SIGNED=false

  while true ; do
      case "$1" in
      --cache_mono)
        CACHE_MONO=true
        ;;
      --repodir)
        REPO_DIR=$2
        shift
        ;;
      --cache)
        CACHE_DIR=$2
        shift
        ;;
      --unsigned)
        SIGNED=false
        ;;
      --version)
        RELEASE_VERSION="$2"
        shift
        ;;
      --releasetype)
        RELEASE_TYPE="$2"
        shift
        ;;
    	--quiet)
        IF_QUIET_SUPPRESS_OUTPUT=" > /dev/null"
        FORWARD_OPTS="$FORWARD_OPTS --$1"
    		;;
      --data)
        TEST_DATA=$2
        shift
        ;;
      --categories)
        TEST_CATEGORIES=$2
        shift
        ;;
      --* | -* )
        echo "unknown option $1, please use --help."
        exit 1
        ;;
      * )
        break
        ;;
      esac
      shift
  done

  RELEASE_CHANGELOG_FILE="${DUPLICATI_ROOT}/changelog.txt"
  RELEASE_CHANGELOG_NEWS_FILE="${DUPLICATI_ROOT}/changelog-news.txt" # never in repo due to .gitignore
  RELEASE_TIMESTAMP=$(date +%Y-%m-%d)
  RELEASE_NAME="${RELEASE_VERSION}_${RELEASE_TYPE}_${RELEASE_TIMESTAMP}"
  RELEASE_FILE_NAME="duplicati-${RELEASE_NAME}"
}