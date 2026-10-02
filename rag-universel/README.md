# Pipeline RAG universel (6 workflows n8n, Supabase, Gemini)

Un pipeline RAG qui n'est lié à aucun document : on indexe n'importe quel fichier dans une **collection**, puis on l'interroge par un chat. Il est découpé en **sous-workflows** réutilisables. La spec complète est dans [`spec.md`](spec.md) ; les tables Supabase sont dans [`schema.sql`](schema.sql).

| Fichier | Rôle |
|---|---|
| [`1-ingestion-orchestrateur.json`](workflows/1-ingestion-orchestrateur.json) | Formulaire (ou webhook) → extraction (rapide ou OCR Markdown) → appelle les sous-workflows 2, 3 et 4 |
| [`2-sous-workflow-chunking.json`](workflows/2-sous-workflow-chunking.json) | Nettoyage, découpage (**récursif**, **sémantique** ou **IA**), chevauchement |
| [`3-sous-workflow-augmentation.json`](workflows/3-sous-workflow-augmentation.json) | Un appel Gemini par groupe de 8 chunks : contexte, résumé, mots-clés, questions, entités, relations |
| [`4-sous-workflow-enregistrement.json`](workflows/4-sous-workflow-enregistrement.json) | Remplace le document dans Supabase ; embeddings par lots de 10, avec attente seulement si Google signale un dépassement de quota |
| [`5-sous-workflow-recherche.json`](workflows/5-sous-workflow-recherche.json) | Embedding des requêtes, recherche SQL, filtre, classement, reranking Gemini |
| [`6-chat-orchestrateur.json`](workflows/6-chat-orchestrateur.json) | Chat : contexte (historique Postgres), routage, appelle le sous-workflow 5, AI Agent |

**Ingestion** : fichier PDF, TXT, MD, HTML, CSV ou RTF → extraction → chunking (stratégie au choix) → augmentation → vectorisation dans Supabase. Garde-fou : entre 50 et 300 chunks (nœud Limit), sinon arrêt avant toute écriture.
**Answering** : contexte → routage (entités, mots-clés, jusqu'à 3 reformulations) → recherche vectorielle → reranking → réponse avec ses sources, ou refus explicite si rien de pertinent.

## Installer

1. **Supabase** : exécuter [`schema.sql`](schema.sql) dans le SQL Editor.
2. **Credentials n8n** (à créer, jamais à partager) :
   - **Postgres**, via la connexion « Session pooler » de Supabase (utilisateur de la forme `postgres.xxxxx`, SSL activé) ;
   - **Google Gemini(PaLM) API**, avec une clé gratuite de Google AI Studio.
3. **Importer les 6 fichiers** (Create workflow → ⋯ → Import from File), **les sous-workflows d'abord** (2, 3, 4, 5), puis les orchestrateurs (1, 6).
4. **Rebrancher** : dans les orchestrateurs, ouvrir chaque nœud « Execute Workflow » (*Chunking*, *Augmentation*, *Enregistrement* dans l'ingestion ; *Recherche* dans le chat) et sélectionner le sous-workflow correspondant.
5. **Attacher les credentials** :
   - Postgres aux nœuds *Supprimer l'ancien document*, *Créer le document*, *Enregistrer en SQL*, *Rechercher en SQL*, *Lire l'historique*, *Enregistrer l'échange* ;
   - Google Gemini aux nœuds HTTP (*Embedding HTTP*, *Embeddings des phrases*, *Embedding de la question*, *OCR Markdown (Gemini)*) et aux nœuds de modèle (*Gemini Flash-Lite…*, *Gemini Flash…*).
6. **Tester** : lancer le formulaire de l'ingestion avec un petit document, collection `test`, « Nombre max de chunks » à `3` ; puis poser une question dans le chat.

## Utiliser

- **Formulaire d'ingestion** : fichier, collection, titre, description, *mode d'extraction (PDF)* (rapide, ou OCR Markdown par Gemini pour un PDF scanné ou structuré), *stratégie de chunking*, et un *nombre max de chunks* optionnel.
- **Mode démo** : avec un nombre max de chunks, seuls les premiers chunks sont traités (le plancher de 50 chunks est levé) et le document reçoit une source distincte (`…::demo`) : un essai partiel ne remplace jamais un document complet.
- **Réindexer** un document (même collection, même titre) remplace ses anciens chunks sans toucher aux autres documents.
- **Chat** : le nœud *Configuration* règle la collection interrogée (`toutes` ou le nom d'une collection) et le seuil de reranking.
- **API** : `POST /webhook/rag-ingestion` avec `{collection, titre, description, texte}` (ou `pdf_base64`), et en option `strategie` (`recursif`, `semantique`, `ia`) et `params`.

## Limites à connaître

- **Quotas de l'offre gratuite de Gemini** : 100 textes d'embeddings par minute (mesuré), environ 15 requêtes par minute et par modèle de texte, environ 1 000 embeddings par jour. L'enrichissement par groupes de 8 chunks et l'attente automatique quand Google signale un dépassement en tiennent compte. Un livre de 160 chunks prenait 7 minutes avec l'ancienne pause fixe entre les lots ; sans elle, comptez environ 3 minutes (estimation, non mesurée sur le livre complet).
- **Modèles** : `gemini-flash-lite-latest` pour l'enrichissement, le chunking IA, l'OCR, le routage et la réponse ; `gemini-3.1-flash-lite` (version fixe) pour le reranking, car avec l'alias `latest` le reranking notait plus sévèrement et la comparaison de deux auteurs perdait l'un d'eux ; `gemini-embedding-001` pour les embeddings. Un alias peut changer de version sans prévenir : les mesures du dépôt valent pour la version du jour.
- La stratégie **sémantique** vectorise chaque phrase : limitée à 100 phrases (quota de 100 textes par minute). L'**OCR Markdown** transcrit tout le PDF en un appel : à réserver aux documents courts ou scannés.
- Les workflows ne sont pas publiés : à activer vous-même si besoin. Ce dépôt ne contient aucun contenu de document, aucune clé et aucun identifiant d'instance.
