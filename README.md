# openssl_installation

Navigate to the [OpenSSL downloads page](https://www.openssl.org/source/) and select any of the versions provided:
 ```
  wget https://www.openssl.org/source/openssl-3.0.14.tar.gz
  tar xzvf openssl-3.0.14.tar.gz
```

Verify the SHA256 checksum of the tarball received with the one given on the website:
```
sha256sum openssl-3.0.14
```
![image](https://github.com/lakshya-chopra/openssl_installation/assets/77010972/9b19a4be-63ea-4b94-a153-315205595598)

Build the library
```
cd openssl-3.0.14
./config -Wl,--enable-new-dtags,-rpath,'$(LIBRPATH)'
make
sudo make install
```
Add the following to your terminal config file (ex : `~/.bashrc`):
```
export OPENSSL_ROOT_DIR=/usr/include/openssl
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
```


[Optional] OQS_PROVIDER Setup:
```
git clone https://github.com/open-quantum-safe/oqs-provider.git
cd oqs-provider
```
Now, make sure you have OpenSSL (v >= 3.0) installed, and your specific branch of liboqs is built against that version, if not, then you may install it using the following script:
```

```
