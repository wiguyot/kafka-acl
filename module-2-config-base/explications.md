## Vue d’ensemble
	- Broker Kafka (KRaft, sans ZooKeeper) avec trois points d’accès :
        •	INTERNAL (intra-cluster, PLAINTEXT),
        •	EXTERNAL (exposé à l’hôte, TLS + SASL/PLAIN),
        •	CLIENT (réseau Docker interne, TLS + SASL/PLAIN).
	-	Comptes gérés par l’image Bitnami : admin, user1.
	-	ACLs appliquées au démarrage par init-acls (topic weather + group weather-group).
	-	Producteur et consommateur Python utilisant SASL/PLAIN et TLS, avec paramètres fournis via variables d’environnement.


    ## Listeners et advertised listeners

### Rôles des listeners
- INTERNAL : 
  
    Usage inter-broker (communication Kafka ↔ Kafka). Ici PLAINTEXT, limité au réseau Docker.
    Avantage : simplicité pour l’IBP. À ne pas exposer hors réseau de confiance.

- EXTERNAL
  
    Point d’accès chiffré destiné aux outils/clients sur l’hôte (ex. localhost:19092).
    Protocole : SASL_SSL (TLS + SASL).

- CLIENT
  
    Point d’accès chiffré destiné aux autres conteneurs du même réseau Docker (ex. kafka:39092).
    Protocole : SASL_SSL (TLS + SASL).
    Avantage : pas besoin de sortir du réseau Docker, ni d’utiliser localhost.


```yaml
# Listeners / Advertised listeners
KAFKA_CFG_LISTENERS: "INTERNAL://:29092,EXTERNAL://:19092,CLIENT://:39092,CONTROLLER://:9093"
KAFKA_CFG_ADVERTISED_LISTENERS: "INTERNAL://kafka:29092,EXTERNAL://localhost:19092,CLIENT://kafka:39092"
KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP: "INTERNAL:PLAINTEXT,EXTERNAL:SASL_SSL,CLIENT:SASL_SSL,CONTROLLER:PLAINTEXT"
KAFKA_CFG_INTER_BROKER_LISTENER_NAME: "INTERNAL"
```

**Points Clés**

	•	Les advertised.listeners doivent refléter le nom d’hôte vu par les clients ciblés :
        •	EXTERNAL://localhost:19092 pour les clients exécutés sur l’hôte,
        •	CLIENT://kafka:39092 pour les conteneurs du réseau Docker.
	•	En cas de mismatch (DNS/ports), les clients échouent à se connecter.

### Authentification

**Qu'est-ce que SASL ?**

**SASL** (Simple Authentication and Security Layer) est un cadre standardisé permettant de brancher différents **mécanismes d’authentification** au-dessus d’un protocole applicatif (ici, Kafka). Kafka supporte plusieurs mécanismes SASL côté client/serveur.

**SASL/PLAIN**

•	**SASL/PLAIN** transporte un couple nom d’utilisateur / mot de passe dans l’échange SASL.

•	Dans ce projet, SASL/PLAIN est systématiquement encapsulé dans TLS (protocole SASL_SSL), donc les identifiants ne circulent pas en clair sur le réseau.

**Alternatives à SASL/PLAIN**

	•	SASL/SCRAM (SCRAM-SHA-256 / SCRAM-SHA-512)
Hash côté serveur, plus robuste que PLAIN pour le stockage des secrets.

	•	SASL/OAUTHBEARER
Délégation via jetons OAuth2 / OIDC (idP externe).

	•	SASL/GSSAPI (Kerberos)
Intégration SSO en environnement Kerberos.

	•	Mutual TLS (mTLS) sans SASL
Authentification client par certificat X.509 (pas SASL, mais souvent une alternative).

**Où c'est configuré dans notre projet (broker)**

```yaml
# Utilisateurs gérés par l'image Bitnami
KAFKA_CFG_SASL_ENABLED_MECHANISMS: "PLAIN"
KAFKA_CFG_SASL_MECHANISM_INTER_BROKER_PROTOCOL: "PLAIN"
KAFKA_CLIENT_USERS: "admin,user1"
KAFKA_CLIENT_PASSWORDS: "admin-secret,user1-secret"

# Autorizer + super users
KAFKA_CFG_AUTHORIZER_CLASS_NAME: "org.apache.kafka.metadata.authorizer.StandardAuthorizer"
KAFKA_CFG_SUPER_USERS: "User:admin;User:ANONYMOUS"
KAFKA_CFG_ALLOW_EVERYONE_IF_NO_ACL_FOUND: "false"
```
Remarque : User:ANONYMOUS n’est toléré ici que pour la démo (facilite l’INTERNAL en PLAINTEXT). À retirer en production.

**Où c'est utilisé dans nos clients pythons**

```python
import os
conf = {
    "security.protocol": "SASL_SSL",
    "sasl.mechanisms": "PLAIN",
    "sasl.username": os.getenv("K_USERNAME"),
    "sasl.password": os.getenv("K_PASSWORD"),
    # ...
}
```

**Dans le docker-compose.yml**

```yaml
environment:
  K_USERNAME: "user1"
  K_PASSWORD: "user1-secret"
```

**Les autorisations (ACL)**

Les **ACLs** sont appliquées par init-acls (idempotent) :

	•	Sur le topic weather : user1 a READ et WRITE. admin a ALL.
	•	Sur le group weather-group : user1 a READ et DESCRIBE.

**Vérification côté broker** :

```bash
/opt/bitnami/kafka/bin/kafka-acls.sh \
  --bootstrap-server kafka:29092 \
  --list --topic weather

/opt/bitnami/kafka/bin/kafka-acls.sh \
  --bootstrap-server kafka:29092 \
  --list --group weather-group
```

### Chiffrement (TLS)

**TLS en mode PEM (côté broker)**

```yaml
KAFKA_ENABLE_TLS: "yes"
KAFKA_TLS_TYPE: "PEM"
KAFKA_TLS_CERTIFICATE_FILE: "/bitnami/kafka/config/certs/kafka.keystore.pem"  # cert serveur
KAFKA_TLS_KEY_FILE: "/bitnami/kafka/config/certs/kafka.keystore.key"          # clé privée serveur
KAFKA_TLS_TRUSTSTORE_FILE: "/bitnami/kafka/config/certs/kafka.truststore.pem" # CA (chaîne)
KAFKA_TLS_CLIENT_AUTH: "none"
KAFKA_CFG_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM: " "  # désactive la vérification SAN (dev seulement)
```

•	PEM : les clés/certificats sont fournis sous forme de fichiers PEM (ASCII base64).

•	Le broker présente son certificat serveur ; les clients le vérifient contre la CA (truststore.pem).

•	En démo, la vérification de l’hostname/SAN est désactivée. En production, activer la vérification SAN et utiliser un certificat correspondant au FQDN annoncé dans advertised.listeners.


**TLS côté clients**

Chaque conteneur Python monte la CA et la référence dans ssl.ca.location :

```yaml
# docker-compose.yaml
volumes:
  - ./conf/certs/kafka.truststore.pem:/certs/ca.crt:ro

environment:
  SSL_CA: "/certs/ca.crt"
```

```python
# producer.py / consumer.py
conf = {
    "security.protocol": "SASL_SSL",
    "ssl.ca.location": os.getenv("SSL_CA", "/app/ca.crt"),
    # ...
}
```

**Résultat** : le trafic est chiffré (TLS) et l’authentification SASL se fait dans le tunnel TLS.

```python
conf = {
    "bootstrap.servers": os.getenv("BOOTSTRAP", "kafka:39092"),
    "security.protocol": "SASL_SSL",
    "ssl.ca.location": os.getenv("SSL_CA", "/app/ca.crt"),
    "sasl.mechanisms": "PLAIN",
    "sasl.username": os.getenv("K_USERNAME"),
    "sasl.password": os.getenv("K_PASSWORD"),
    "client.id": "py-producer",  # ou py-consumer
}
```
**kafka:39092** => nom du container "kafka", port adressé sur le container : 39092

Dans l'environnement docker du container producer/consumer on va retrouver cette référence : 

```yaml
environment:
  BOOTSTRAP: "kafka:39092"
```

### divers tests

Si on veut vérifier ce qui est déjà "tombé" dans le topic kafka "weather" depuis le container kafka : 

```bash
/opt/bitnami/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server kafka:29092 \
  --topic weather \
  --from-beginning \
  --timeout-ms 10000
  ```

  Vérifier les ACLs depuis le container kafka: 

  ```bash
  /opt/bitnami/kafka/bin/kafka-acls.sh \
  --bootstrap-server kafka:29092 --list --topic weather

/opt/bitnami/kafka/bin/kafka-acls.sh \
  --bootstrap-server kafka:29092 --list --group weather-group
  ```

  ### Bonnes pratiques

  	•	Mauvais advertised.listeners : toujours utiliser le nom/host visible côté client (ex. kafka dans le réseau Docker, localhost sur l’hôte).
    
	•	SAN/Hôte TLS : en production, ne pas désactiver la vérification de SAN ; délivrer des certificats pour les FQDN annoncés.

	•	ACLs des consumer groups : un consumer a besoin des droits sur le group (READ/DESCRIBE), pas seulement sur le topic.

	•	Secrets en clair : éviter les valeurs par défaut en dur pour K_USERNAME/K_PASSWORD. Préférer des secrets Docker/compose ou un gestionnaire de secrets.
	•	PLAINTEXT exposé : le listener INTERNAL doit rester confiné au réseau de confiance (Docker). Ne jamais l’exposer publiquement.