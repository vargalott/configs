```sh
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout ./dummy.key -out ./dummy.crt -subj "/CN=invalid.local"
```