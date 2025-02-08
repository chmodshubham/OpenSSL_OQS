# OQS Provider setup:

Here, we'll set up a complete quantum safe TLS/SSL dev environment, using OpenSSL (v >= 3.0.0), alongside [liboqs](https://github.com/open-quantum-safe/liboqs) & the [oqs-provider](https://github.com/open-quantum-safe/oqs-provider) . So let's proceed with this.

- To not corrupt our existing installation of OpenSSL, we'll create a new folder, where the latest release of OpenSSL will be installed.

  ## Setup the WORKDIR & install the dependencies
- ```sh
  mkdir pqtls
  cd pqtls

  export WORKSPACE=~/pqtls 
  export BUILD_DIR=$WORKSPACE/build #will contain the build artifacts
  mkdir -p $BUILD_DIR
  ```
- ```sh
  sudo apt update
  sudo apt -y install git build-essential perl cmake autoconf libtool zlib1g-dev
  ```
- We'll be using autoconf and libtool to configure our builds.

  ## Install OpenSSL:
  ```sh
  cd $WORKSPACE
  
  git clone https://github.com/openssl/openssl.git
  cd openssl
 
  ./Configure \
  --prefix=$BUILD_DIR \
  --openssldir=$BUILD_DIR/ssl \
  -Wl,-rpath,$BUILD_DIR/lib64 -Wl,--enable-new-dtags \
  shared no-tls1 no-tls1_1 no-afalgeng \
  threads -lm enable-sctp
  
  # The no-afalgeng option disables the OpenSSL AF_ALG crypto engine.

  make -j
  #sudo make -j install_sw install_ssldirs
  sudo make install -j
  ```
  [Note: On 64 bit systems, the library directory will default to `lib64`. For 32 bit systems & macOS, change lib64 to lib in the RPATH & subsequent environment variables]
  Other installation options can be explored [here](https://github.com/openssl/openssl/blob/master/INSTALL.md)
  
  ## Next up, we'll build liboqs against the OpenSSL version just installed:
  ```sh
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
  ```
The option `DOQS_BUILD_ONLY_LIB=ON` can be turned `OFF` to add testing & prettyprint scripts. 
 ## Install oqs-provider:
  ```sh
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
  sed -i "s/default = default_sect/default = default_sect\noqsprovider = oqsprovider_sect/g" $BUILD_DIR/ssl/openssl.cnf &&
  sed -i "s/\[default_sect\]/\[default_sect\]\nactivate = 1\n\[oqsprovider_sect\]\nactivate = 1\n/g" $BUILD_DIR/ssl/openssl.cnf

```
![image](https://github.com/user-attachments/assets/5b0f1437-528d-4998-b4dc-b46db472f570)

### openssl.cnf
![image](https://github.com/lakshya-chopra/openssl_installation/assets/77010972/18be795b-c395-41e5-82c6-97c7c1448861)


- Next, make sure you add the new openssl conf and modules to your env variables (modules is the path to the dir where OpenSSL will find the oqs-provider):
```sh
export OPENSSL_CONF=$BUILD_DIR/ssl/openssl.cnf
export OPENSSL_MODULES=$BUILD_DIR/lib64/ossl-modules
```

- At the end, your build dir structure should look like this:
![image](https://github.com/lakshya-chopra/openssl_installation/assets/77010972/88874c44-72f6-4379-8e8f-e0a0b2345b11)
where, the `include` dir has the headers of OpenSSL, and liboqs & `bin` stores the actual executables (cli).

- You can also use the option while building the oqs-provider: ```-OQS_PROVIDER_BUILD_STATIC=ON```, to make a static library (.a) instead of a shared one (.so).
- For a static lib, the following code can be run:
```c
#include <openssl/provider.h>

extern OSSL_provider_init_fn oqs_provider_init;

void load_oqs_provider(OSSL_LIB_CTX *libctx) {
  int err;

  if (OSSL_PROVIDER_add_builtin(libctx, "oqsprovider", oqs_provider_init) == 1) {
    if (OSSL_PROVIDER_load(libctx, "oqsprovider") == 1) {
      fprintf(stderr,"successfully loaded `oqsprovider`.");
    } else {
      fprintf(stderr ,"failed to load `oqsprovider`", stderr);
    }
  } else {
    fprintf(stderr,"failed to add the builtin provider `oqsprovider`");
  }
}
```
Set the `LD_LIBRARY_PATH`:  ```export LD_LIBRARY_PATH=$BUILD_DIR/lib:$BUILD_DIR/lib64:$LD_LIBRARY_PATH``` 

and then run using ```gcc -o main main.c -I$BUILD_DIR/include/openssl -I$WORKSPACE/oqs-provider/oqsprov -L$BUILD_DIR/lib -L$BUILD_DIR/lib64 -lssl -lcrypto -loqs``` (Note -L befor -l, so that the Gnu Linker only searches the paths we have specified)

- for a dynamic lib instead, we make use of the `OSSL_PROVIDER_load` method, example:
```c
    provider = OSSL_PROVIDER_load(libctx, kOQSProviderName);
    if (provider == NULL) {
        fputs("`OSSL_PROVIDER_load` failed\n", stderr);
        return -1;
    }
```

## Run oqs-prov tests:
- Python unittest (install `pytest` & `pytest-xdist` beforehand)
```sh
cd oqs-provider/scripts
python3 test_tls_full.py --ossl=$BUILD_DIR/bin/openssl --ossl-config=$BUILD_DIR/ssl/openssl.cnf --test-artifacts-dir=$WORKSPACE/oqs-provider/scripts/artifacts -n $nproc
```
- For running the tests below, certain environment variables need to be set: (Check [oqsprovider/scripts/fullbuild.sh](https://github.com/open-quantum-safe/oqs-provider/blob/main/scripts/fullbuild.sh))
  - `OPENSSL_INSTALL` - directory where OpenSSL is installed, script `fullbuild.sh` will automatically locate the `OPENSSL_APP` via that (though we can set that manually too)
  - `OPENSSL_BRANCH`
  - `liboqs_DIR`
  - `LIBOQS_BRANCH`
  - `OPENSSL_CONF` : path to openssl.cnf with OQS provider support.
  - `OPENSSL_MODULES`: path to the directory storing oqsprovider's shared/static library.
```sh
cd oqs-provider
scripts/fullbuild.sh && scripts/runtests.sh -V
```
- If using `feature/dtls-1.3` branch, the results will be like this:
![image](https://github.com/user-attachments/assets/26f0c9cd-10d4-4733-8725-5843fe887365)
- The executables of the code files located in `oqs-provider/test` are available in the `oqs-provider/_build/test` dir. As an example, we can run them as follows:
```sh
./oqs_test_groups "oqsprovider" $BUILD_DIR/ssl/openssl.cnf $WORKSPACE/oqs-provider/test
```

## Test the setup by running the below commands:
```sh
openssl list -providers -verbose
openssl list -kem-algorithms -provider oqsprovider
```

![image](https://github.com/lakshya-chopra/openssl_installation/assets/77010972/9fcae985-243b-4c98-b055-a90f0622955c) <br/> <hr/>
![image](https://github.com/lakshya-chopra/openssl_installation/assets/77010972/70112cc1-f6a7-4bc7-874c-db66a8a1ef8e)

## Create Post quantum certificates and CA authorities:
We can make use of any signature algorithms [given here](https://github.com/open-quantum-safe/oqs-provider/blob/main/ALGORITHMS.md) for this task. I'm going to use **MLDSA87_x448**, which is a hybrid signature scheme consisting of **MLDSA87** (earlier known as Dilithium5) and **Ed448**. 

- Generating the CA certificate and CA key:
```
openssl req -x509 -new -newkey mldsa87_ed448 -keyout mldsa87_ed448_CA.key -out mldsa87_ed448_CA.crt -nodes -subj "/CN=test CA" -days 365 
```
![image](https://github.com/user-attachments/assets/9fabe65b-945a-49f7-a8ba-b897d5d05b1f)

It's a really big key, roughly 1/4th part is shown here.

- Next, generate the server's key and send a CSR to the CA just created, approve the CSR and generate the cert:
```
openssl req -new -newkey mldsa87_ed448 -keyout mldsa87_ed448_srv.key -out mldsa87_ed448_srv.csr -nodes -subj "/CN=server"
openssl x509 -req -in mldsa87_ed448_srv.csr -out mldsa87_ed448_srv.crt -CA mldsa87_ed448_CA.crt -CAkey mldsa87_ed448_CA.key -CAcreateserial -days 365
```
Hybrid PQC is used here, because in case if MLDSA turns out to be unsafe, then our keys and certs will still be as secure as "Ed448".

- Connect using `s_client` & `s_server`:
```sh
openssl s_server -cert mldsa87_ed448_srv.crt -key mldsa87_ed448_srv.key -dtls1_3 -groups X25519MLKEM768
```
```sh
openssl s_client -groups X25519MLKEM768 -dtls1_3
```


