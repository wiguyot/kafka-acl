# Module 1 – Kafka en mode KRaft


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

```yaml
# ACL lecture
kafka-acls.sh \
  --bootstrap-server broker-1:9092,broker-2:9092,broker-3:9092 \
  --add \
  --allow-principal User:user-topic1 \
  --operation Read \
  --topic topic1

# ACL écriture
kafka-acls.sh \
  --bootstrap-server broker-1:9092,broker-2:9092,broker-3:9092 \
  --add \
  --allow-principal User:user-topic1 \
  --operation Write \
  --topic topic1

```

    Attention seul l'utilisateur user-topic1 pourra écrire ou lire donc produire ou consommer y compris en ligne de commande. Il faut absolument utiliser SASL/SSL pour s'authentifier. A défaut on est ANONYMOUS


## Bénéfices : simplification, haute disponibilité, sécurité centralisée

| Bénéfice               | Description                                                                                              |
|------------------------|----------------------------------------------------------------------------------------------------------|
| Simplification         | Plus besoin de déployer ni de maintenir ZooKeeper : tout est géré par les brokers Kafka.                 |
| Haute disponibilité    | Quorum RAFT tolérant aux pannes : perte d’un contrôleur n’impacte pas l’écriture des topics.              |
| Sécurité centralisée   | Gestion unifiée des ACL et métadonnées via l’Admin CLI/API ; plus d’accès direct à ZooKeeper.            |
| Opérations atomiques   | Création de topics et modifications d’ACL transactionnelles et cohérentes via RAFT.                      |

