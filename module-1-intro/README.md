# Module 1 – Kafka en mode KRaft

Introduction aux ACL en kafka

## Historique : ZooKeeper → KRaft

### Contexte initial

Depuis ses débuts, Apache Kafka utilisait ZooKeeper pour gérer ses métadonnées : configuration du cluster, liste des brokers, élection des leaders de partition et ACL.

### Limitations de ZooKeeper

    Complexité opérationnelle : double administration (Kafka + ZooKeeper)

    Latence : allers-retours supplémentaires entre brokers et ZooKeeper

    Risque de point de blocage : une panne de ZooKeeper peut rendre le cluster Kafka indisponible

### Passage à KRaft

    Objectif : internaliser la gestion des métadonnées dans Kafka

    Évolutions clés :

        Kafka 2.8 : preview KRaft

        Kafka 3.3 : KRaft GA (production-ready)

    Architecture RAFT : un quorum de contrôleurs Kafka se coordonne directement pour stocker et répliquer les métadonnées

## Admin CLI : opérations sur topics et ACL sans ZooKeeper

    Remarque : toutes les commandes s’exécutent en mode KRaft, via --bootstrap-server broker-1:9092,broker-2:9092,broker-3:9092.

### Créer un topic

```yaml
kafka-topics \
  --bootstrap-server broker-1:9092,broker-2:9092,broker-3:9092 \
  --create \
  --topic secure-topic \
  --partitions 3 \
  --replication-factor 2
```

### Lister les topics

```yaml
kafka-topics \
  --bootstrap-server broker-1:9092,broker-2:9092,broker-3:9092 \
  --list
```

### Ajouter une ACL

Autoriser User:analytics à READ sur sensitive-data


```yaml
kafka-acls \
  --bootstrap-server broker-1:9092,broker-2:9092,broker-3:9092 \
  --add \
  --allow-principal User:broker-1 \
  --operation Read \
  --topic sensitive-data
```

### Lister les ACL existantes

```yaml
kafka-acls \
  --bootstrap-server broker-1:9092,broker-2:9092,broker-3:9092 \
  --list
```

### Supprimer une ACL
Révoquer DELETE pour User:producer1 sur secure-topic

```yaml
kafka-acls \
  --bootstrap-server broker-1:9092,broker-2:9092,broker-3:9092 \
  --remove \
  --allow-principal User:broker-1 \
  --operation Read \
  --topic sensitive-data
```

### créer une ACL read-write pour l'utilisateur user-topic1 sur topic1

Attention : il n'est pas nécessaire que le topic existe pour préparer les ACL !!!

```yaml
# ACL lecture
kafka-acls \
  --bootstrap-server broker-1:9092,broker-2:9092,broker-3:9092 \
  --add \
  --allow-principal User:user-topic1 \
  --operation Read \
  --topic topic1

# ACL écriture
kafka-acls \
  --bootstrap-server broker-1:9092,broker-2:9092,broker-3:9092 \
  --add \
  --allow-principal User:user-topic1 \
  --operation Write \
  --topic topic1
```

Point d'attention : 

- Avec un pattern literal, seules les ACL pour ce nom exact s’appliqueront.
- Avec un pattern prefixed ou le wildcard '*', les ACL s’appliqueront à tous les topics dont le nom matche le préfixe ou le wildcard.
- Si vous avez configuré ```allow.everyone.if.no.acl.found=false``` (propriété souvent recommandée pour un mode ```« deny-by-default »```), toute opération sans ACL explicite sera refusée, d’où l’intérêt de pré-provisionner vos ACL pour les topics à venir.



    Attention seul l'utilisateur user-topic1 pourra écrire ou lire donc produire ou consommer y compris en ligne de commande. Il faut absolument utiliser SASL/SSL pour s'authentifier. A défaut on est ANONYMOUS


## Bénéfices : simplification, haute disponibilité, sécurité centralisée

| Bénéfice               | Description                                                                                              |
|------------------------|----------------------------------------------------------------------------------------------------------|
| Simplification         | Plus besoin de déployer ni de maintenir ZooKeeper : tout est géré par les brokers Kafka.                 |
| Haute disponibilité    | Quorum RAFT tolérant aux pannes : perte d’un contrôleur n’impacte pas l’écriture des topics.              |
| Sécurité centralisée   | Gestion unifiée des ACL et métadonnées via l’Admin CLI/API ; plus d’accès direct à ZooKeeper.            |
| Opérations atomiques   | Création de topics et modifications d’ACL transactionnelles et cohérentes via RAFT.                      |



## Sécurisation SASL (sans chiffrement)

Pour que Kafka prenne en compte vos ACL, il faut impérativement :

1. **Configurer l’authorizer** dans `server.properties` (chaque broker)  
```yaml
authorizer.class.name=kafka.security.authorizer.AclAuthorizer

allow.everyone.if.no.acl.found=false
```

2. Activer un listener SASL_PLAINTEXT

```yaml
listeners=SASL_PLAINTEXT://0.0.0.0:9092
listener.name.sasl_plaintext.scram-sha-512.sasl.jaas.config=
  org.apache.kafka.common.security.scram.ScramLoginModule required
  username="admin"
  password="admin-secret";
```

3. Utiliser SASL_PLAINTEXT dans les commandes CLI
   
- Créer un fichier ```client_sasl_plaintext.properties``` :

```yaml
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=\
  org.apache.kafka.common.security.scram.ScramLoginModule required\
  username="analytics"\
  password="analytics-secret";
```

- Exécuter :

```yaml
kafka-acls \
  --bootstrap-server broker-1:9092,broker-2:9092 \
  --command-config client_sasl_plaintext.properties \
  --add \
  --allow-principal User:analytics \
  --operation Read \
  --topic sensitive-data
```

**ATTENTION : Comme il n’y a pas de chiffrement, toutes les données transitent en clair – à réserver au développement ou tests, non recommandé en production.**