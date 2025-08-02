# configs

## vps init
```sh
curl -fsSL https://raw.githubusercontent.com/vargalott/configs/refs/heads/main/init.sh | bash
```

## some stuff
```sh
ssh -p <port> user@host -L <local_port>:127.0.0.1:<remote_port>

bash <(curl -Ls IP.Check.Place) -l en
wget -qO - "https://raw.githubusercontent.com/vernette/ipregion/refs/heads/master/ipregion.sh" | bash
bash <(curl -Ls check.unlock.media) -E en -R 0
wget -qO- bench.sh | bash
wget -qO- nws.sh | bash

certbot certonly --standalone --agree-tos -m EMAIL -d DOMAIN
certbot renew --dry-run

uuidgen

echo "$(tr -dc a-z </dev/urandom | head -c2)$((RANDOM%9+1))--$(tr -dc a-z0-9 </dev/urandom | head -c13)-$( ( [ $((RANDOM%2)) -eq 0 ] && printf '%02d' $((RANDOM%90+10)) ) || echo $(tr -dc a-z </dev/urandom | head -c1)$((RANDOM%9+1)) )"
```
