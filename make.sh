#!/usr/bin/env bash

# make.sh
#
# Copyright (C) 2020 Kristofer Berggren
# All rights reserved.
#
# See LICENSE for redistribution information.

# exiterr
exiterr()
{
  >&2 echo "${1}"
  exit 1
}

# process arguments
DEPS="0"
BUILD="0"
TESTS="0"
DOC="0"
INSTALL="0"
case "${1%/}" in
  deps)
    DEPS="1"
    ;;

  build)
    BUILD="1"
    ;;

  test*)
    BUILD="1"
    TESTS="1"
    ;;

  doc)
    BUILD="1"
    DOC="1"
    ;;

  install)
    BUILD="1"
    INSTALL="1"
    ;;

  all)
    DEPS="1"
    BUILD="1"
    TESTS="1"
    DOC="1"
    INSTALL="1"
    ;;

  *)
    echo "usage: make.sh <deps|build|tests|doc|install|all>"
    echo "  deps      - install project dependencies"
    echo "  build     - perform build"
    echo "  tests     - perform build and run tests"
    echo "  doc       - perform build and generate documentation"
    echo "  install   - perform build and install"
    echo "  all       - perform all actions above"
    exit 1
    ;;
esac

# deps
if [[ "${DEPS}" == "1" ]]; then
  OS="$(uname)"
  if [ "${OS}" == "Linux" ]; then
    DISTRO="$(lsb_release -i | awk -F':\t' '{print $2}')"
    if [[ "${DISTRO}" == "Ubuntu" ]]; then
      sudo apt -y install ccache cmake build-essential gperf help2man libreadline-dev libssl-dev libncurses-dev libncursesw5-dev ncurses-doc zlib1g-dev || exiterr "deps failed (linux), exiting."
    else
      exiterr "deps failed (unsupported linux distro ${DISTRO}), exiting."
    fi
  elif [ "${OS}" == "Darwin" ]; then
    brew install gperf cmake openssl ncurses ccache readline || exiterr "deps failed (mac), exiting."
  else
    exiterr "deps failed (unsupported os ${OS}), exiting."
  fi
fi

# build
if [[ "${BUILD}" == "1" ]]; then
  OS="$(uname)"
  if [ "${OS}" == "Linux" ]; then
    MEM="$(( $(($(getconf _PHYS_PAGES) * $(getconf PAGE_SIZE) / (1000 * 1000 * 1000))) * 1000 ))" # in MB
  elif [ "${OS}" == "Darwin" ]; then
    MEM="$(( $(($(sysctl -n hw.memsize) / (1000 * 1000 * 1000))) * 1000 ))" # in MB
  fi

  MEM_NEEDED_PER_CORE="3500" # tdlib under g++ needs 3.5 GB
  if [[ "$(c++ -dM -E -x c++ - < /dev/null | grep CLANG_ATOMIC > /dev/null ; echo ${?})" == "0" ]]; then
    MEM_NEEDED_PER_CORE="1500" # tdlib under clang++ needs 1.5 GB
  fi

  MEM_MAX_THREADS="$((${MEM} / ${MEM_NEEDED_PER_CORE}))"
  if [[ "${MEM_MAX_THREADS}" == "0" ]]; then
    MEM_MAX_THREADS="1" # minimum 1 core
  fi

  if [[ "${OS}" == "Darwin" ]]; then
    CPU_MAX_THREADS="$(sysctl -n hw.ncpu)"
  else
    CPU_MAX_THREADS="$(nproc)"
  fi

  if [[ ${MEM_MAX_THREADS} -gt ${CPU_MAX_THREADS} ]]; then
    MAX_THREADS=${CPU_MAX_THREADS}
  else
    MAX_THREADS=${MEM_MAX_THREADS}
  fi

  MAKEARGS="-j${MAX_THREADS}"
  echo "using ${MAKEARGS} (${CPU_MAX_THREADS} cores, ${MEM} MB phys mem, ${MEM_NEEDED_PER_CORE} MB mem per core needed)"
  mkdir -p build && cd build && cmake .. && make -s ${MAKEARGS} && cd .. || exiterr "build failed, exiting."
fi

# tests
if [[ "${TESTS}" == "1" ]]; then
  true || exiterr "tests failed, exiting."
fi

# doc
if [[ "${DOC}" == "1" ]]; then
  if [[ -x "$(command -v help2man)" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
      SED="gsed -i"
    else
      SED="sed -i"
    fi
    help2man -n "ncurses chat" -N -o src/nchat.1 ./build/bin/nchat && ${SED} "s/\.\\\\\" DO NOT MODIFY THIS FILE\!  It was generated by help2man.*/\.\\\\\" DO NOT MODIFY THIS FILE\!  It was generated by help2man./g" src/nchat.1 || exiterr "doc failed, exiting."
  fi
fi

# install
if [[ "${INSTALL}" == "1" ]]; then
  OS="$(uname)"
  if [ "${OS}" == "Linux" ]; then
    cd build && sudo make install && cd .. || exiterr "install failed (linux), exiting."
  elif [ "${OS}" == "Darwin" ]; then
    cd build && make install && cd .. || exiterr "install failed (mac), exiting."
  else
    exiterr "install failed (unsupported os ${OS}), exiting."
  fi
fi

# exit
exit 0
