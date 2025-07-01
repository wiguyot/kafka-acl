# Cours : Gestion des ACL Kafka via Kafdrop (Mode KRaft, sans ZooKeeper)


## Objectifs pédagogiques

1) Comprendre l’architecture Kafka en mode KRaft (sans ZooKeeper)

2) Installer et configurer Kafdrop pour administrer topics et ACL

3) Mettre en place l’authentification (SSL ou SASL) pour les clients

4) Gérer les autorisations (ACL) via l’interface Kafdrop

5) Appliquer le principe du moindre privilège et automatiser le déploiement des ACL


## Plan du cours

| Module | Contenu & Activités                                                                                                                                                                   |    Durée   |
| :----: | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :--------: |
|    1   | **Introduction à Kafka en mode KRaft**<br>– Évolution ZooKeeper → KRaft<br>– Nouveautés de l’Admin API pour la sécurité                                                               |   45 min   |
|    2   | **Installation et configuration de Kafdrop**<br>– Déploiement Docker / Kubernetes<br>– Paramétrage SSL/SASL<br>– Sécurisation de l’accès à l’UI                                       |     1 h    |
|    3   | **Authentification Kafka**<br>– SSL mutualisé vs SASL SCRAM<br>– Génération de certificats et users SCRAM<br>– Configuration brokers & clients                                        |     1 h    |
|    4   | **Principes d’ACL Kafka**<br>– Principals, Resources, Opérations<br>– Différences Admin API vs ancien modèle ZooKeeper                                                                |   45 min   |
|    5   | **Gestion des ACL via Kafdrop**<br>– Lister, ajouter, modifier, supprimer une règle<br>– Démonstrations UI guidées                                                                    |   1 h 30   |
|    6   | **Exercices pratiques**<br>1. Restreindre la lecture d’un topic `sensitive-data`<br>2. Autoriser un service à créer et décrire tous les topics<br>3. Révoquer un droit de suppression |     1 h    |
|    7   | **Audit, supervision & bonnes pratiques**<br>– Export JSON des ACL via API REST<br>– GitOps (Terraform / Ansible)<br>– Revue périodique                                               |     1 h    |
|    8   | **Atelier final**<br>– Cluster KRaft multi-nœuds + Kafdrop HA<br>– Pipeline CI pour ACL déclaratives<br>– Checklist de sécurité                                                       |   1 h 30   |
|        | **Total**                                                                                                                                                                             | **8 h 30** |

## Détail des modules


### Module 1 – Kafka en mode KRaft

    Historique : ZooKeeper → KRaft

    Admin API : opérations sur topics et ACL sans accès direct à ZooKeeper

    Bénéfices : simplification, haute disponibilité, sécurité centralisée

### Module 2 – Installation et configuration de Kafdrop

    Via Docker

docker run -d \
  -p 9000:9000 \
  -e KAFKA_BROKERCONNECT=kafka-broker1:9092 \
  -e JVM_OPTS="-Xms32M -Xmx64M" \
  obsidiandynamics/kafdrop

Connexion SSL

-e KAFKA_TRUSTSTORE_LOCATION=/path/to/truststore.jks \
-e KAFKA_TRUSTSTORE_PASSWORD=changeit \
-e KAFKA_KEYSTORE_LOCATION=/path/to/keystore.jks \
-e KAFKA_KEYSTORE_PASSWORD=changeit

Connexion SASL SCRAM

    -e KAFKA_SASL_MECHANISM=SCRAM-SHA-512 \
    -e KAFKA_SASL_JAAS_CONFIG="org.apache.kafka.common.security.scram.ScramLoginModule required username='user' password='pwd';"

    Sécurisation de l’UI

        Reverse-proxy (Nginx + basic auth)

        OAuth2 proxy / Authentification SSO

### Module 3 – Authentification Kafka

    SSL mutualisé

        Création d’une CA interne

        Génération de keystores (keytool)

        Configuration listeners et client.listeners

    SASL SCRAM

        Avec l’Admin API :

    kafka-configs.sh --bootstrap-server kafka-broker1:9092 \
      --alter --add-config 'SCRAM-SHA-512=[iterations=4096,password=monMdp]' \
      --entity-type users --entity-name analytics

Tests

    kafka-topics.sh --bootstrap-server kafka-broker1:9092 \
      --command-config client.properties --list

### Module 4 – Principes d’ACL Kafka

    Principal

        User:serviceA (SASL)

        CN=client (SSL)

    ResourceType

        Topic, Group, TransactionalID, Cluster

    Opérations
    Opération	Description
    Read	Consommer des messages
    Write	Produire des messages
    Create	Créer topics / groupes de consom.
    Delete	Supprimer topics
    Describe	Lister / voir configuration
    Alter	Modifier configuration
    ClusterAction	Actions spécifiques au cluster

### Module 5 – Gestion des ACL dans Kafdrop

    Lister

        Accéder au menu ACL et filtrer par principal ou topic

    Ajouter

        Formulaire « Add ACL » : choisir principal, resource, opérations

    Modifier / Supprimer

        Boutons d’action en ligne

    Démonstration

    - Autoriser `User:alice` à **Create** & **Describe** tous les topics  
    - Restreindre **Read** sur `sensitive-data` au `User:analytics`  
    - Révoquer **Delete** sur `secure-topic` pour `User:producer1`

### Module 6 – Exercices pratiques

    Exercice 1

        Créez un principal SCRAM analytics

        Dans Kafdrop, ajoutez une ACL Read sur sensitive-data

    Exercice 2

        Créez un principal serviceX

        Autorisez-le à Create et Describe tous les topics

    Exercice 3

        Supprimez via l’UI l’ACL Delete pour secure-topic / producer1

### Module 7 – Audit, supervision & bonnes pratiques

    Export JSON des ACL via l’API REST de Kafdrop

    GitOps

        Terraform Provider Kafka pour déclarer les ACL en code

        Ansible modules Kafka

    Revue périodique

        Principe du moindre privilège

        Rotation des credentials

### Module 8 – Atelier final

    Déploiement d’un cluster KRaft (3 contrôleurs, 3 brokers)

    Kafdrop HA (Helm Chart, réplication)

    CI/CD

        Pipeline GitOps pour appliquer les ACL

    Livrable

        Playbook Terraform/Ansible + rapport de sécurité

    Total estimé : 8 h 30
    Résultat attendu : maîtrise complète de la gestion des ACL Kafka via Kafdrop, sans jamais toucher à ZooKeeper.