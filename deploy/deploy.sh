#!/bin/sh -e

PYVER=3.4.1
COMPRESSION=xz

if [ -z "$1" ]; then
  echo "You must specify either \"pre\" or \"post\" command" 1>&2
  exit 1
fi

root=$(readlink -f $(dirname $(readlink -f $0))/..)
path=$root/deploy
cpus=$(getconf _NPROCESSORS_ONLN)

do_pre() {
  echo "Running git archive..."
  cd $root
  git archive --format=tar HEAD -o $path/Veles.tar
  cd $root/veles/znicz
  git archive --format=tar --prefix veles/znicz/ HEAD -o $path/Znicz.tar
  cd $root/deploy/pyenv
  git archive --format=tar --prefix deploy/pyenv/ HEAD -o $path/pyenv.tar
  cd $root/mastodon
  git archive --format=tar --prefix mastodon/ HEAD -o $path/Mastodon.tar
  cd $path
  echo "Merging archives..."
  tar --concatenate --file Veles.tar Znicz.tar
  tar --concatenate --file Veles.tar pyenv.tar
  tar --concatenate --file Veles.tar Mastodon.tar
  rm Znicz.tar pyenv.tar Mastodon.tar
  echo "Compressing..."
  rm -f Veles.tar.$COMPRESSION
  $COMPRESSION Veles.tar
  echo "$path/Veles.tar.$COMPRESSION is ready"
}

setup_distribution() {
  if [ ! -e /etc/lsb-release ]; then
    echo "/etc/lsb-release was not found => unable to determine your Linux distribution" 1>&2
    return
  fi
  . /etc/lsb-release
  case "$DISTRIB_ID" in
  "Ubuntu"):
      major=$(echo $DISTRIB_RELEASE | cut -d . -f 1)
      if [ $major -lt 14 ]; then
        echo "Ubuntu older than 14.04 is not supported" 1>&2
        exit 1
      fi
      packages=$(cat ../ubuntu-apt-get-install-me.txt | tail -n +7 | sed -r -e 's/^\s+//g' -e 's/\\//g' | tr '\n' ' ')
      sudo apt-get install -y $packages
      ;;
  "CentOS"):
      echo "CentOS"
      ;;
  "Fedora"):
      echo "Fedora"
      ;;
  *) echo "Did not recognize your distribution \"$DISTRIB_ID\"" 1>&2 ;;
  esac
}

do_post() {
  setup_distribution
  cd $path
  . ./init-pyenv
  versions=$(pyenv versions | grep $PYVER || true)
  if [ -z "$versions" ]; then
    pyenv install $PYVER
  fi
  pyenv local $PYVER

  vroot=$path/pyenv/versions/$PYVER
  if [ ! -e $vroot/lib/libsodium.so ]; then
    git clone https://github.com/jedisct1/libsodium
    cd libsodium && mkdir build
    ./autogen.sh && cd build
    ../configure --prefix=$vroot --disable-static
    make -j$cpus && make install
    cd ../.. && rm -rf libsodium
  fi

  if [ ! -e $vroot/lib/libpgm.so ]; then
    svn checkout http://openpgm.googlecode.com/svn/trunk/ openpgm
    cd openpgm/openpgm/pgm && mkdir build
    patch if.c < ../../../openpgm.patch
    autoreconf -i -f && cd build
    ../configure --prefix=$vroot --disable-static
    make -j$cpus && make install
    cd ../../../.. && rm -rf openpgm
  fi

  if [ ! -e $vroot/lib/libzmq.so.4 ]; then
    git clone https://github.com/vmarkovtsev/libzmq.git
    cd libzmq && mkdir build
    ./autogen.sh && cd build
    ../configure --prefix=$vroot --disable-static --without-documentation --with-system-pgm --with-libsodium-include-dir=$vroot/include --with-libsodium-lib-dir=$vroot/lib PKG_CONFIG_PATH=$vroot/lib/pkgconfig PKG_CONFIG_LIBDIR=$vroot/lib
    make -j$cpus && make install
    cd ../.. && rm -rf libzmq
  fi

   pip3 install cython
   pip3 install git+https://github.com/vmarkovtsev/twisted.git
   PKG_CONFIG_PATH=$vroot/lib/pkgconfig pip3 install -r $root/requirements.txt
}

case "$1" in
  "pre"):
     do_pre
     ;;
  "post"):
     do_post
     ;;
esac
