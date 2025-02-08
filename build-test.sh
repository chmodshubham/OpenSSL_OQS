#!/bin/bash

# Args:
BENCHMARK=0

display_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --benchmark      Run benchmark tests (default: 0)"
    echo "  --list-algorithms  List all available signature and KEM algorithms"
    echo "  -h, --help       Show this help message"
    echo
}


while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --benchmark)
            BENCHMARK=1
            ;;
        --list-algorithms)
            LIST_ALGORITHMS=1
            ;;
        -h|--help)
            display_help
            exit 0
            ;;
        *)
            echo "Invalid option: $1"
            display_help
            exit 1
            ;;
    esac
    shift
done



# Install the required packages
sudo apt update
sudo apt -y install git build-essential perl cmake autoconf libtool zlib1g-dev

# Directory & Environment variables
mkdir pqtls
cd pqtls

export WORKSPACE=~/pqtls
export BUILD_DIR=$WORKSPACE/build

mkdir -p $BUILD_DIR

cd $WORKSPACE
git clone https://github.com/openssl/openssl.git
cd openssl
git checkout 98acb6b 

./Configure \
  --prefix=$BUILD_DIR \
  --openssldir=$BUILD_DIR/ssl \
  -Wl,-rpath,$BUILD_DIR/lib64 -Wl,--enable-new-dtags \
  shared no-tls1 no-tls1_1 no-afalgeng \
  threads -lm

# The no-afalgeng option disables the OpenSSL AF_ALG crypto engine.

make -j$nproc
sudo make install -j$nproc

#liboqs installation
cd $WORKSPACE

git clone https://github.com/open-quantum-safe/liboqs.git
cd liboqs
mkdir build && cd build

cmake \
   -DCMAKE_INSTALL_PREFIX=$BUILD_DIR \
   -DBUILD_SHARED_LIBS=ON \
   -DOQS_USE_OPENSSL=OFF \
   -DCMAKE_BUILD_TYPE=Release \
   -DOQS_BUILD_ONLY_LIB=ON \
   -DOQS_DIST_BUILD=ON \
   ..

make -j
sudo make -j install

#oqs installation
cd $WORKSPACE

git clone https://github.com/open-quantum-safe/oqs-provider.git
cd oqs-provider

liboqs_DIR=$BUILD_DIR/lib/cmake cmake \
  -DCMAKE_INSTALL_PREFIX=$WORKSPACE/oqs-provider \
  -DOPENSSL_ROOT_DIR=$WORKSPACE/openssl \
  -DCMAKE_BUILD_TYPE=Release \
  -S . \
  -B _build
cmake --build _build

# Copy the built lib to our standard workspace build dir
cp _build/lib/* $BUILD_DIR/lib64/ossl-modules

# Edit the openssl.cnf to add oqs-provider to the list of providers.
sudo sed -i "s/default = default_sect/default = default_sect\noqsprovider = oqsprovider_sect/g" $BUILD_DIR/ssl/openssl.cnf &&
sudo sed -i "s/\[default_sect\]/\[default_sect\]\nactivate = 1\n\[oqsprovider_sect\]\nactivate = 1\n/g" $BUILD_DIR/ssl/openssl.cnf


# more envs
export OPENSSL_CONF=$BUILD_DIR/ssl/openssl.cnf
export OPENSSL_MODULES=$BUILD_DIR/lib64/ossl-modules
export LD_LIBRARY_PATH=$BUILD_DIR/lib:$BUILD_DIR/lib64:$LD_LIBRARY_PATH


# Benchmark
DURATION=5

SIGNATURE_ALGORITHMS="ed25519 ecdsa mldsa65 mldsa44 mldsa87 falcon512 dilithium3 rsa3072"
KEM_ALGORITHMS="rsa3072 X25519 X448 ecdh mlkem768 mlkem512 mlkem1024 frodo976aes frodo976shake bikel5 hqc192"
OPENSSL_APP=$BUILD_DIR/bin/openssl

list_algorithms(){
    echo "Signature algorithms:"
    list -signature-algorithms -provider oqsprovider
    echo -e "KEM algorithms:"
    $OPENSSL_APP list -kem-algorithms -provider oqsprovider
}

signature_benchmark() {
    echo "Running OpenSSL benchmark for signature algorithms for $DURATION seconds: $SIGNATURE_ALGORITHMS"
    $OPENSSL_APP speed -seconds $DURATION --signature-algorithms $SIGNATURE_ALGORITHMS
}

kem_benchmark() {
    echo "Running OpenSSL benchmark for KEM algorithms for $DURATION seconds: $KEM_ALGORITHMS"
    $OPENSSL_APP speed -seconds $DURATION -kem-algorithms $KEM_ALGORITHMS
}


if [[ "$LIST_ALGORITHMS" -eq 1 ]]; then
    list_algorithms
fi

if [[ "$BENCHMARK" -eq 1 ]]; then
    echo -e "Benchmarking..."
    signature_benchmark
    kem_benchmark
fi
