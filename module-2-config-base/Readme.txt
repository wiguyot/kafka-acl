kafka-kraft-acl-tls/
├─ docker-compose.yml
├─ conf/
│  ├─ env.kafka               # variables partagées (optionnel)
│  └─ certs/                  # JKS + CA exporté en PEM
│     ├─ ca.crt               # CA en PEM (pour Python)
│     ├─ kafka.keystore.jks   # clé+cert serveur (JKS)
│     ├─ kafka.truststore.jks # truststore côté broker
│     └─ passwords.txt        # mots de passe des stores (lecture seule)
├─ init/
│  └─ create-acls-and-topic.sh
├─ app/
│  ├─ requirements.txt
│  ├─ producer.py
│  └─ consumer.py
└─ tools/
   └─ gen-certs.sh            # génère JKS + export CA (à lancer une fois)