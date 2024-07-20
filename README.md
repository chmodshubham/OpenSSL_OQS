# openssl_installation

Navigate to the [OpenSSL downloads page](https://www.openssl.org/source/) and select any of the versions provided:
 ```sh
  wget https://www.openssl.org/source/openssl-3.0.14.tar.gz
  tar xzvf openssl-3.0.14.tar.gz
```

Verify the SHA256 checksum of the tarball received with the one given on the website:
```sh
sha256sum openssl-3.0.14
```
![image](https://github.com/lakshya-chopra/openssl_installation/assets/77010972/9b19a4be-63ea-4b94-a153-315205595598)

Build the library
```sh
cd openssl-3.0.14
./config -Wl,--enable-new-dtags,-rpath,'$(LIBRPATH)' --prefix=/usr/local/ enable-sctp
make
sudo make install
```
**Prefix** specifies the parent directory where the **lib64** will be built, `enable-sctp` builds openssl with sctp suport. You may also specify the location where you want `openssl.cnf` should be added. [Read more build config options here](https://github.com/openssl/openssl/blob/master/INSTALL.md#directories)

Add the following to your terminal config file (ex : `~/.bashrc`):
```sh
export OPENSSL_ROOT_DIR=/usr/include/openssl
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
```
