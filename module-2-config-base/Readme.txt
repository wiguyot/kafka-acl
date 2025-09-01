# des trucs à écrire pour documenter

Un premier exemple de configuration kafka (kraft) qui utilise les ACLs ainsi que le chiffrement.

L'idée est de créer : 
	•	Un broker Kafka
        - Déployer via docker-compose, configuré en mode KRaft (sans Zookeeper).
        - Il expose plusieurs listeners, dont un listener chiffré (SASL_SSL) pour les clients externes au container.
	•	Des utilisateurs
        - Définis via SASL/PLAIN (admin, user1), avec mot de passe.
	•	Des droits associés aux utilisateurs
        - Gérés par ACLs (init/create-acls-and-topic.sh).
        - Exemple : user1 a le droit de produire et consommer sur le topic weather.
        - admin a les droits complets (ALL) sur le cluster et le topic.
	•	Un producteur
        - app/producer.py publie régulièrement des messages dans le topic weather.
        - Il se connecte en SASL/SSL (authentification + chiffrement).
	•	Un consommateur
        - app/consumer.py lit les messages du topic weather.
        - Il utilise aussi SASL/SSL pour s’authentifier et chiffrer sa connexion.

## liste des fichiers les plus pédagogiquement importants

/Users/wiguyot/kafka-acl/module-2-config-base
├── app
├── conf
│   └── certs
├── docker-compose.yaml
├── init
│   └── create-acls-and-topic.sh
├── Readme.txt
└── tools
    └── gen-certs.sh

## liste de tous les fichiers

/Users/wiguyot/kafka-acl/module-2-config-base
├── app
│   ├── Clermont-Ferrand.epw
│   ├── consumer.py
│   ├── producer.py
│   └── requirements.txt
├── conf
│   └── certs
│       ├── ca.crt
│       ├── ca.ext
│       ├── ca.key
│       ├── ca.srl
│       ├── csr.conf
│       ├── kafka.keystore.key
│       ├── kafka.keystore.pem
│       ├── kafka.truststore.pem
│       ├── kafka.truststore.srl
│       ├── server.crt
│       ├── server.csr
│       └── server.key
├── docker-compose.yaml
├── init
│   └── create-acls-and-topic.sh
├── Readme.txt
└── tools
    └── gen-certs.sh




**Test de lecture des enregistrement du topic "weather"**

```bash
docker exec -it kafka bash -lc "/opt/bitnami/kafka/bin/kafka-console-consumer.sh --bootstrap-server kafka:29092 --topic weather --from-beginning --timeout-ms 10000"
```
