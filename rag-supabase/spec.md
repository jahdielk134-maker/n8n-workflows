# Spec : RAG sur un livre avec Supabase (Les 100 citations de la philosophie)

Basée sur le template du cours « Create a Documentation Expert Bot with RAG, Gemini, and Supabase » (n8n, n° 5993) et sur la spec du premier RAG (Simple Vector Store), dont elle reprend les règles sauf mention contraire.

## Objectif
Exercice de cours n8n : refaire le RAG du livre *Les 100 citations de la philosophie* avec une base **persistante** dans **Supabase** (table `embedding`), en montrant les deux faces, Ingestion et Answering, et chacune de leurs étapes. Réussite : une démo en direct devant le prof où l'on charge (ou retrouve) le livre, puis où le chat répond en français avec ses sources, à partir de Supabase.

## Déclencheurs
| Face | Déclencheur |
|---|---|
| Ingestion | Envoi du PDF via un formulaire (On form submission) |
| Answering | Message reçu dans le chat (When chat message received) |

## Entrées
- **Ingestion :** le PDF du livre.
- **Answering :** une question en texte libre.

## Sorties
- **Ingestion :** la table `embedding` de Supabase remplie (un chunk par ligne, avec texte, métadonnées et vecteur). Succès ou échec visible dans l'historique d'exécutions.
- **Answering :** une réponse en français, avec pour chaque source utilisée la citation, le philosophe et le numéro de la citation.
- **Livrable :** le workflow exporté en JSON dans le dépôt GitHub, sans donnée du livre ni secret.

## Écosystème
- n8n Cloud (essai), nouveau workflow dédié.
- **Supabase** (projet gratuit déjà prêt) : table `embedding` à la structure standard du template, plus sa fonction de recherche par similarité.
  - Colonnes : `id`, `content` (texte du chunk), `metadata` (JSON : numero, citation, philosophe, dates, epoque, paragraphe), `embedding` (vecteur).
  - Le modèle d'embedding par défaut de Gemini produit des vecteurs de 3 072 valeurs. Cette taille dépasse la limite des index pgvector classiques (2 000) ; avec environ 134 lignes, une recherche sans index est instantanée et suffit.
- **Gemini avec une clé personnelle** (Google AI Studio, ajoutée comme credential dans n8n) **uniquement pour les embeddings** : l'embedding d'une question n'est pas pris en charge par les crédits Gateway. Même modèle d'embedding à l'insertion et à la recherche. Les nœuds de texte (enrichissement, sélection, reranking, agent) gardent les crédits Gateway, car une clé gratuite limite le nombre d'appels par minute et l'enrichissement en fait une centaine de suite.
- Briques imposées par le prof : AI Agent, Supabase Vector Store, Gemini pour les embeddings.
- Modèles de texte : `gemini-3-flash-preview` (enrichissement, génération), `gemini-3.1-flash-lite` (sélection, reranking), comme au premier RAG.
- **Secrets :** la clé `service_role` de Supabase et la clé Gemini restent dans les credentials n8n. Jamais dans le chat, dans le workflow exporté ou dans GitHub.

## Règles métier

### Face 1 : Ingestion
Consignes du prof : un item par chunk, **entre 50 et 300 chunks** pour tout le livre ; chunking avec **découpage récursif** et **chevauchement** (le chunking par embeddings et par fenêtre glissante d'IA est écarté : trop lent) ; augmentation avec **contexte, cleaning, questions hypothétiques, mots-clés, entités et relations** ; un nœud **Limit** pour protéger le pipeline.

1. **Extraction** du PDF.
2. **Cleaning** : ne garder que les 100 citations et leurs commentaires.
3. **Chunking** : découpage structurel (citation, puis paragraphe de commentaire), puis **découpage récursif** (un paragraphe de plus de 1 200 caractères est coupé aux fins de phrase, puis aux mots), puis **chevauchement** de 150 caractères avec le chunk précédent de la même citation. Résultat attendu : environ 170 chunks.
4. **Augmentation** : métadonnées (philosophe, époque, numéro, partie) et un appel Gemini par citation qui produit **contexte** (1 à 2 phrases qui situent la citation dans le livre), **résumé**, **mots-clés**, **questions hypothétiques**, **entités** (personnes, concepts, œuvres, lieux) et **relations** (sujet, relation, objet), plus l'époque. Tout est ajouté au texte de chaque chunk.
5. **Garde-fous** : un contrôle arrête l'ingestion avec une erreur claire si le nombre de chunks est hors de 50 à 300 (avant toute écriture dans la base), suivi d'un nœud **Limit** à 300.
6. **Vectorisation** (voir ci-dessous).
- **Vectorisation vers Supabase :** les chunks sont enrichis **avant** toute écriture. Puis la table `embedding` est **vidée** et les nouveaux chunks sont insérés (une ré-ingestion remplace tout, sans doublon).
- **Insertion par lots :** les chunks sont insérés par lots de 10 avec une pause de 25 secondes entre les lots. Raison (constatée en réel) : envoyer 100 chunks d'un coup à l'API d'embedding gratuite renvoie des vecteurs vides sans erreur. Durée d'une ingestion : environ 15 minutes (enrichissement puis insertion).
- **Tout ou rien côté enrichissement :** si Gemini échoue pendant l'enrichissement, l'ingestion s'arrête avant de toucher la table.

### Face 2 : Answering (hybride)
1. **Input :** réception de la question.
2. **Sélection :** Gemini détecte salutation ou question, les philosophes et l'époque cités, et reformule la question pour la recherche.
3. **Recherche :** les 40 chunks les plus proches dans Supabase, puis filtre par philosophe ou époque après la recherche (comparaison : on garde tout).
4. **Reranking :** Gemini note les chunks de 0 à 10 à partir d'un aperçu ; les 5 meilleurs au-dessus du seuil de 6 passent à la génération, plus le meilleur passage de chaque philosophe cité en cas de comparaison (score d'au moins 4).
5. **Génération par l'AI Agent :** réponse en français uniquement à partir des extraits, avec section « Sources » (citation, philosophe, numéro). L'agent garde une **mémoire de la conversation** pour la rédaction (par exemple « résume en une phrase »).
6. **Refus :** si aucun chunk n'est pertinent, réponse « je ne trouve pas dans le livre » ; pas de connaissances générales.

## Cas limites
| Situation | Comportement attendu |
|---|---|
| Le PDF est envoyé deux fois | La table est vidée puis remplie : même nombre de lignes, aucun doublon |
| Question comparative ou citant plusieurs philosophes | Recherche large sans filtre, un passage par philosophe cité |
| Question dans une autre langue | Réponse en français |
| Message vide ou « salut » | Réponse courte d'invitation, sans recherche |
| Question hors sujet | Refus explicite |
| Table vide (livre non chargé) | Message indiquant que le livre n'est pas chargé |
| Redémarrage de n8n | La base survit : les questions marchent sans ré-ingérer (avantage de Supabase) |
| Fichier non exploitable | L'ingestion échoue avec une erreur claire, la table n'est pas touchée |

## Gestion des erreurs
| Panne | Comportement attendu |
|---|---|
| Gemini indisponible ou quota dépassé pendant l'enrichissement | Arrêt avant écriture (3 tentatives), alerte dans l'historique, table intacte |
| Supabase injoignable ou refus d'accès | Erreur explicite dans l'historique, aucune réponse inventée |
| Échec pendant l'insertion après le vidage | La table peut rester vide ou partielle : relancer l'ingestion (limite acceptée pour l'exercice) |
| Panne pendant une question | Message d'erreur clair dans le chat, sans réponse inventée |

## Contraintes
- **Droit d'auteur :** le PDF, le texte extrait et les chunks ne vont jamais dans GitHub. L'export du workflow est générique (le nœud Cleaning demande de renseigner le pied de page du PDF).
- **Secrets :** aucun identifiant, URL de projet Supabase ou clé dans l'export.
- **Coût :** quota gratuit de Supabase et de Gemini.
- **Temps de réponse :** moins de 30 secondes par réponse.
- Le workflow n'est pas publié sans ton accord.

## Critères d'acceptation
- [ ] Étant donné le PDF, quand je l'envoie via le formulaire, alors la table `embedding` contient entre 50 et 300 lignes (environ 170), chacune avec contenu (contexte, entités et relations inclus), métadonnées et vecteur non vide.
- [ ] Quand je renvoie le même PDF, alors la table contient toujours le même nombre de lignes.
- [ ] Étant donné un PDF qui donnerait moins de 50 ou plus de 300 chunks, alors l'ingestion s'arrête avant d'écrire dans la table, avec un message d'erreur clair.
- [ ] Étant donné la table remplie, quand je demande « Que veut dire « je pense, donc je suis » ? », alors la réponse cite Descartes, citation n° 40.
- [ ] Quand je demande « Que dit Sartre sur les autres ? », alors la réponse s'appuie sur « L'enfer, c'est les autres ».
- [ ] Quand je demande la capitale de l'Australie, alors le système refuse.
- [ ] Quand je compare Descartes et Pascal, alors les sources viennent des deux auteurs.
- [ ] Après une réponse, quand je demande « résume en une phrase », alors la réponse s'appuie sur la conversation (mémoire de l'agent).
- [ ] Étant donné une table vide, quand je pose une question, alors le message « livre non chargé » s'affiche.
- [ ] Étant donné une panne simulée de Gemini à l'enrichissement, alors la table reste inchangée.
- [ ] Les réponses arrivent en moins de 30 secondes.
- [ ] Le workflow montre les deux faces et leurs étapes ; l'export JSON est dans le dépôt, sans donnée du livre ni secret.

## Points à décider
- **Mémoire et questions de suivi :** la sélection et le reranking ne regardent que le message courant. Une relance comme « et Pascal ? » seule ne sera pas comprise ; seule la rédaction profite de la mémoire. À améliorer si la démo le demande.
- **Nom de la fonction de recherche :** `match_embedding` proposé ; le nœud Supabase Vector Store permet de choisir le nom.
- **Disponibilité du modèle d'embedding** avec ta clé : à vérifier au premier test (repli : modèle 768 dimensions si besoin).
- **Questions de la démo :** liste de 5 ou 6 questions éprouvées, à fixer après les tests.
