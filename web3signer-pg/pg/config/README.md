Generate keys using https://github.com/usmansaleem/signer-configuration-generator

```shell
cd signer-configuration-generator
./gradlew clean installdist
./build/install/signer-configuration-generator/bin/signer-configuration-generator keystores \
  --count=2000 \
  --output <path_of_pg/config.keys> \
  --outputDirInConfig /var/config/keys
```