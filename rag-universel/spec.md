# Spec : pipeline RAG universel en sous-workflows (Supabase, Gemini, AI Agent)

Suite des deux RAG sur *Les 100 citations de la philosophie* (qui restent tels quels). Ici le pipeline n'est plus lié à ce livre : n'importe quel document peut être indexé dans une **collection**, puis interrogé par un chat. Il suit les consignes du prof (tableau d'ingestion et tableau d'answering) : sous-workflows, extraction en Markdown (OCR), chunking (overlap, récursif, embeddings, sémantique/IA), augmentation (contexte, cleaning, questions hypothétiques, mots-clés, entités et relations), vectorisation ; puis contexte, routage, recherche, reranking, génération. Garde-fous 50 à 300 chunks avec nœud Limit.

*Dernière mise à jour : 2 octobre 2026, après construction et tests réels (voir « Critères d'acceptation » pour ce qui est prouvé et ce qui ne l'est pas).*

## Objectif
Un pipeline **universel et réutilisable** : une face Ingestion qui accepte des documents de types variés et une face Answering qui répond avec ses sources à partir d'une collection, construits à partir de **sous-workflows** (blocs indépendants, testables seuls, appelables par d'autres workflows). Réussite : démo en direct où l'on indexe un document, puis un second document d'un tout autre sujet, sans modifier le moindre nœud, et où le chat répond correctement sur chacun.

## Déclencheurs
| Workflow | Déclencheur |
|---|---|
| Ingestion (orchestrateur) | Formulaire (voir Entrées) ou appel API (webhook POST) |
| Answering (orchestrateur) | Message dans le chat n8n |
| Sous-workflows (Chunking, Augmentation, Enregistrement, Recherche) | « When Executed by Another Workflow » |

## Entrées
- **Formulaire d'ingestion :**
  - un fichier **PDF, TXT, MD, HTML, CSV ou RTF** ;
  - la **collection** (par exemple « philosophie ») ;
  - le **titre** et une **courte description** du document (tout le reste est déduit par Gemini) ;
  - le **mode d'extraction (PDF)** : *Rapide (texte)* ou *OCR Markdown (Gemini)* ;
  - la **stratégie de chunking** : *Récursif* (défaut), *Sémantique (embeddings)* ou *IA (Gemini)* ;
  - un **nombre max de chunks** optionnel (mode démo : seuls les premiers chunks sont traités, le plancher de 50 chunks est levé).
- **API (webhook) :** `{collection, titre, description, texte` **ou** `pdf_base64, strategie?, params?}`. Même pipeline que le formulaire ; sert aussi aux tests.
- **Answering :** une question en texte libre ; la collection interrogée (une collection ou « toutes ») et les réglages (nombre de passages cherchés : 40, seuil de reranking : 6) sont dans le nœud « Configuration ».

## Sorties
- **Ingestion :** le document et ses chunks dans Supabase, dans des tables **reliées par identifiant** : `rag_documents` (collection, titre, description, source), `rag_chunks` (contenu, contexte, résumé, questions, métadonnées), `rag_embeddings` (vecteur de 3 072 valeurs), `rag_mots_cles`, `rag_entites`, `rag_relations` (suppression en cascade). Message de fin : « Document indexé : N chunks dans la collection X ».
- **Answering :** une réponse en français avec ses sources au format « Titre du document (extrait n° X) — entité principale » ; l'échange est enregistré dans `rag_messages`.

## Écosystème
- n8n Cloud (essai) ; Supabase (extension pgvector, fonction de recherche `rag_match_chunks`) ; Gemini avec la **clé personnelle** pour tout (les crédits Gateway sont épuisés et n'acceptent pas les embeddings de requête).
- **Six workflows :**
  - Ingestion (orchestrateur) → sous-workflows **Chunking**, **Augmentation**, **Enregistrement** ;
  - Chat (orchestrateur) → sous-workflow **Recherche**.
- Modèles : `gemini-3.1-flash-lite` (augmentation, chunking IA, OCR, sélection, reranking), `gemini-3-flash-preview` (réponse de l'agent), `gemini-embedding-001` (embeddings).
- Les deux workflows précédents (Simple Vector Store, Supabase table `embedding`) sont conservés intacts.

## Règles métier

### Face 1 : Ingestion
1. **Extraction :** routage par type de fichier. PDF en *Rapide* (texte brut), PDF en *OCR Markdown* (Gemini lit le PDF et renvoie du Markdown : titres, listes, tableaux), texte brut, HTML (balises retirées), CSV (une ligne devient un paragraphe « colonne : valeur »), RTF. Une transcription OCR tronquée est refusée.
2. **Chunking (sous-workflow) :** nettoyage générique (césures, numéros de page, en-têtes répétés ; en Markdown, structure conservée), puis découpage selon la **stratégie** :
   - *Récursif* : on regroupe les paragraphes jusqu'à 1 200 caractères, un paragraphe trop long est coupé aux phrases puis aux mots ;
   - *Sémantique* : chaque phrase est vectorisée et on coupe là où la ressemblance entre phrases voisines chute (limité à 400 phrases, à cause du quota gratuit d'embeddings) ;
   - *IA* : Gemini choisit les points de coupure, fenêtre par fenêtre (8 000 caractères) ;
   - dans tous les cas : **overlap** (reprise de 1 à 2 phrases entières de 150 caractères environ du chunk précédent) ; en Markdown, chaque chunk commence par sa section (« Section : H1 > H2 ») et l'overlap ne traverse pas deux sections.
3. **Garde-fous :** le nombre de chunks doit être entre 50 et 300 (modifiable). Hors bornes : arrêt avant tout appel Gemini et toute écriture, avec un message clair. Un nœud **Limit** plafonne ensuite. Avec un « nombre max de chunks » (démo, test), le plafond de 300 et le plancher de 50 ne s'appliquent plus.
4. **Augmentation (sous-workflow) :** **un appel Gemini par groupe de 8 chunks** (deux appels en parallèle) ; chaque chunk reçoit son propre enrichissement : contexte, résumé, mots-clés, questions hypothétiques, entités (avec type), relations (sujet, relation, objet). Tout est ajouté au texte à vectoriser.
5. **Vectorisation / enregistrement (sous-workflow) :** l'ancien document **de même collection et même titre** est supprimé (pas les autres), puis les chunks sont insérés **par lots de 10 avec 15 secondes de pause** (limite des embeddings gratuits). Tout l'enrichissement est terminé avant la moindre écriture. Un lot qui renvoie des vecteurs vides arrête l'ingestion avec un message clair.

### Face 2 : Answering (suit le tableau du prof : Contexte → Routage → Recherche → Reranking → Génération)
1. **Contexte :** nœud Configuration ; **historique** des 10 derniers messages de la session lu dans Postgres (`rag_messages`) ; branche « conversation vide » ; chaque échange est enregistré en fin de réponse.
2. **Routage (sélection) :** Gemini détecte salutation ou question, puis produit les **entités** citées (filtre), les **mots-clés** (classement) et **jusqu'à 3 reformulations** de la question. Une relance (« résume », « et lui ? ») est reformulée avec le sujet de la conversation grâce à l'historique.
3. **Recherche (sous-workflow) :** une recherche vectorielle par reformulation (40 chunks, dans la collection configurée), résultats fusionnés (un chunk garde sa meilleure similarité), filtre souple sur les entités (on garde tout si le filtre ne laisse rien), classement favorisant les passages qui contiennent les mots-clés.
4. **Reranking :** Gemini flash-lite note chaque passage de 0 à 10 sur l'extrait entier, par rapport à la **question autonome** (la première reformulation) ; on garde les 5 meilleurs au-dessus du seuil de 6. Pour une question qui cite plusieurs entités, le meilleur passage de chacune est gardé (score d'au moins 4).
5. **Refus** explicite si rien n'est pertinent ; pas de connaissances générales.
6. **Génération** par l'AI Agent, avec l'historique dans son contexte : réponse en français, uniquement à partir des extraits, avec une section « Sources » (titre, numéro d'extrait, entité principale).

## Cas limites
| Situation | Comportement attendu |
|---|---|
| Un document est réindexé | Seuls ses anciens chunks sont remplacés ; les autres documents sont intacts |
| Essai avec un « nombre max de chunks » (démo, test) | Le document reçoit une source distincte (`…::demo`) : il ne peut jamais remplacer un document complet de même collection et même titre ; un nouvel essai ne remplace que l'essai précédent |
| Type de fichier non géré | Erreur claire à l'entrée, aucune écriture |
| Document hors de 50 à 300 chunks | Arrêt avant écriture, avec le nombre de chunks obtenu (sauf mode « nombre max de chunks ») |
| PDF scanné en mode Rapide | Erreur « aucun texte extrait », avec le conseil d'essayer l'OCR Markdown |
| OCR trop long pour une seule transcription | Erreur claire, conseil d'utiliser le mode Rapide |
| Stratégie sémantique sur plus de 400 phrases | Erreur claire, conseil d'utiliser « récursif » ou « IA » |
| Question hors sujet pour la collection | Refus explicite |
| Collection vide ou inexistante | Message indiquant qu'aucun document n'est indexé |
| Salutation ou message vide | Réponse courte d'invitation, sans recherche |
| Relance dans la même conversation (« résume ») | Résolue grâce à l'historique |
| Question dans une autre langue | Réponse en français |

## Gestion des erreurs
| Panne | Comportement attendu |
|---|---|
| Gemini renvoie « trop de requêtes » (429) pendant l'enrichissement | 5 tentatives ; sinon arrêt avant toute écriture, table intacte |
| Erreur temporaire de Google pendant le chat (503) | 5 tentatives automatiques, puis message d'erreur clair |
| Vecteurs vides renvoyés par l'API d'embeddings | Arrêt avec message clair ; le document peut rester partiel : relancer l'ingestion |
| Échec de l'enregistrement de l'historique | La réponse est quand même renvoyée |
| Un sous-workflow échoue | L'erreur remonte à l'orchestrateur avec le nom de l'étape |

## Contraintes
- **Universel :** aucune règle propre au livre dans les workflows ; seulement des paramètres et la description du document.
- **Droit d'auteur :** aucun contenu de document, identifiant, URL Supabase ni clé dans les exports ou sur GitHub ; documents de test rédigés pour l'occasion.
- **Secrets :** clés Supabase et Gemini uniquement dans les credentials n8n.
- **Quotas de la clé gratuite :** 15 requêtes par minute par modèle (flash-lite) ; environ 1 000 embeddings par jour ; l'enrichissement se fait par groupes de 8 chunks pour rester dans la limite.
- **Durées mesurées :** livre entier (161 chunks) en **6 min 51 s** (enrichissement 1 min 46, embeddings environ 5 min) ; réponse du chat de 9 à 14 secondes. **Estimation non mesurée :** une démo avec 60 chunks devrait prendre 2 à 3 minutes.
- Rien n'est publié sans accord.

## Critères d'acceptation
Légende : [x] prouvé par un test réel ; [ ] non prouvé ou non rejoué (la note dit pourquoi).

- [x] Le PDF du livre dans la collection « philosophie » donne 161 chunks (entre 50 et 300), avec vecteurs non vides et métadonnées (collection, titre, entités, mots-clés).
- [x] Un **second document d'un autre sujet** dans une autre collection s'indexe sans modifier aucun nœud et le chat y répond : « Quelle mouture pour un espresso, et quelle pression ? » donne « mouture fine, neuf bars » avec la source du guide PDF (collection `test-ocr`).
- [x] **Les chunks du livre restent intacts quand on indexe un autre document** : prouvé après incident. Le 2 octobre, un test en mode démo lancé dans la collection `philosophie` avec le même titre a remplacé les 161 chunks du livre par 3 (comportement voulu pour une réindexation, mais dangereux pour un test) ; corrigé (source `…::demo`, voir « Cas limites »), livre réindexé (161 chunks en 7 min 25 s), et les questions sur Descartes et la comparaison Descartes/Pascal répondent à nouveau (15 à 20 s).
- [x] Réindexer un document ne remplace que ses chunks (validé lors des tests précédents du pipeline).
- [x] « Que veut dire « je pense, donc je suis » ? » : la réponse cite Descartes avec ses sources (extraits 74 et 75), en 12 s.
- [x] Une question hors sujet (recette de ratatouille) donne un refus, en 6 s ; une salutation reçoit l'accueil sans recherche.
- [x] Une comparaison de deux entités (Descartes et Pascal) s'appuie sur des passages des deux, sources avec le nom du philosophe.
- [x] Une relance (« Résume ça en une phrase ») est comprise grâce à l'historique Postgres. *Testée avec un identifiant de session fixe ; pas encore par toi dans l'interface du chat.*
- [x] Les stratégies de chunking **sémantique** et **IA** donnent un chunk par sujet sur un texte de 8 sujets distincts. *Cas facile ; pas encore essayées sur un vrai livre.*
- [x] L'**OCR Markdown** transcrit un PDF de test (titres, liste, accents) et les sections sont détectées ; testé par l'API et par le formulaire avec un vrai fichier.
- [x] Le formulaire avec le mode « Rapide (texte) » sur un PDF fonctionne (test du 2 octobre).
- [x] Un document hors de 50 à 300 chunks est refusé avant toute écriture, avec un message clair : un texte court envoyé par l'API s'arrête au nœud « Contrôle du nombre de chunks » (« Nombre de chunks hors limites : 1 (attendu : entre 50 et 300)… Aucune écriture dans la base ») sans appel à Gemini.
- [x] Chaque sous-workflow s'exécute seul avec un jeu de données d'entrée (vérifié dans l'historique d'exécutions).
- [x] Les réponses arrivent en moins de 30 secondes (9 à 14 s mesurées).
- [ ] L'export JSON de tous les workflows est dans le dépôt, sans secret ni contenu de document : à faire, sur accord.

## Décisions prises et limites connues
- **Un appel Gemini par groupe de 8 chunks, et non plus par chunk** (décision initiale modifiée) : la clé gratuite limite à 15 requêtes par minute, l'enrichissement du livre passait de 26 minutes à moins de 2. Chaque chunk garde son enrichissement propre.
- **Table partagée :** le RAG Supabase précédent vide **toute** la table `embedding` ; le pipeline universel utilise d'autres tables (`rag_*`), donc les deux ne se gênent pas.
- **HTML et RTF :** les balises et codes sont retirés par des règles simples, qui marchent pour du texte courant mais pas à tous les coups.
- **L'OCR d'un livre entier** n'a pas été mesuré (durée, limite de 65 000 jetons de sortie) : à réserver aux documents courts ou scannés.
- **La stratégie sémantique** consomme le quota d'embeddings (une requête par phrase) : limitée à 400 phrases.
- **Reranker du prof (« Jev »)** : non identifié, laissé de côté ; le reranking utilise Gemini flash-lite.
- **Embeddings :** l'étape de 5 minutes pour le livre vient du débit de la clé gratuite ; une clé payante ou un réglage de pause plus fin la réduirait, sans test à ce jour.
