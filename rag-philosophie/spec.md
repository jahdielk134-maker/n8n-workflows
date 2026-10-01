# Spec : Study case Rag — RAG sur « Les 100 citations de la philosophie »

## Objectif
Exercice de cours n8n : construire un RAG sur le livre *Les 100 citations de la philosophie* (L. Devillairs), en montrant clairement les deux faces d'un RAG, **Ingestion** et **Answering**, et chacune de leurs étapes. Réussite : on charge le livre, on pose des questions en français dans un chat, et on obtient des réponses fondées sur le livre, avec leurs sources.

## Déclencheurs
| Face | Déclencheur |
|---|---|
| Ingestion | Envoi d'un fichier via un formulaire (On form submission) |
| Answering | Message reçu dans le chat (When chat message received) |

## Entrées
- **Ingestion :** un fichier PDF du livre, envoyé par toi via le formulaire.
- **Answering :** une question en texte libre posée dans le chat.

## Sorties
- **Ingestion :** une base vectorielle contenant les chunks du livre, enrichis. Un retour de succès ou d'échec dans l'historique d'exécutions.
- **Answering :** une réponse rédigée en français, accompagnée pour chaque source utilisée de la citation, du philosophe et du numéro de la citation.

## Écosystème
- Instance n8n Cloud (essai), workflow « Study case Rag », construit et testé avec le serveur MCP de n8n.
- Briques retenues : Extract from File, Google Gemini (enrichissement, sélection, reranking, génération), embeddings OpenAI `text-embedding-3-small` (via les crédits Gateway), Simple Vector Store (en mémoire).
- **Pourquoi OpenAI pour les embeddings :** les crédits Gateway refusent l'embedding d'une question avec Gemini (erreur « Gateway credits don't currently support this operation »). L'insertion et la recherche utilisent le même modèle, sinon les vecteurs ne sont pas comparables. Repli prévu : une clé Gemini personnelle.
- **Modèles Gemini :** `gemini-3-flash-preview` pour l'enrichissement et la génération ; `gemini-3.1-flash-lite` pour la sélection et le reranking (le premier réglage mesurait 35 s par réponse, le second environ 9 à 14 s).
- **Pas d'AI Agent :** chaque étape (sélection, reranking, génération) est un appel Gemini explicite, pour que les deux faces et leurs étapes restent visibles dans le workflow.
- Le Simple Vector Store n'a pas de filtre par métadonnées : le filtrage se fait après la recherche.

## Règles métier

### Face 1 : Ingestion
1. **Extraction :** lire le texte du PDF.
2. **Cleaning :** ne garder que les 100 citations et leurs commentaires. Retirer la page éditeur, la table des matières, l'introduction et les mentions parasites (pied de page répété, mentions d'éditeur ou de remerciement). Recoller les lignes coupées par la mise en page. (Les accents et guillemets du PDF sont corrects : vérifié, aucun caractère corrompu.)
3. **Chunking :** un chunk par paragraphe de commentaire. Si les frontières de paragraphes ne sont pas détectables de façon fiable, repli : découpage par taille (environ 800 caractères) à l'intérieur de chaque citation. Chaque chunk garde le titre de la citation et le philosophe, et commence par le nom du philosophe dans son texte.
4. **Augmentation :** deux volets.
   - Métadonnées : philosophe, époque, numéro de la citation (position dans la table des matières), citation.
   - Enrichissement par Gemini : résumé, mots-clés, questions types et époque. **Un appel par citation** (environ 100 appels), dont le résultat est appliqué à tous les chunks de cette citation. L'époque est classée dans une liste fixe : Antiquité, Moyen Âge, Renaissance, XVIIe siècle, Lumières, XIXe siècle, XXe siècle.
5. **Vectorisation :** stocker les chunks enrichis dans la base vectorielle.
6. **Ré-ingestion :** un nouvel envoi remplace entièrement la base. Pas de doublons.

### Face 2 : Answering
1. **Input :** réception de la question.
2. **Sélection :**
   - Gemini détecte si la question est une salutation ou un message vide, et repère un philosophe ou une époque éventuels.
   - Reformulation de la question par Gemini pour améliorer la recherche.
3. **Recherche :** récupération des 40 chunks les plus proches.
   - **Filtrage par métadonnées** (philosophe, époque) appliqué après la recherche, quand la question n'en mentionne qu'un. S'il ne reste aucun chunk, ou si plusieurs philosophes sont cités, on garde tous les chunks.
4. **Reranking :** Gemini note chaque chunk de 0 à 10 selon sa pertinence, à partir d'un aperçu (en-tête, résumé, mots-clés) pour rester rapide. Seuls les 5 meilleurs au-dessus du seuil de 6 passent à la génération. Pour une question qui cite plusieurs philosophes, le meilleur passage de chacun est aussi gardé (score d'au moins 4), pour que la comparaison s'appuie sur les deux auteurs. Si aucun chunk n'atteint le seuil, c'est le refus.
5. **Génération :** réponse en français avec, pour chaque source utilisée, la citation, le philosophe et le numéro.
6. **Refus :** si aucun chunk n'est pertinent, le système répond qu'il ne trouve pas la réponse dans le livre. Il ne répond pas avec des connaissances générales.

## Cas limites
| Situation | Comportement attendu |
|---|---|
| Le PDF est envoyé deux fois | La base est remplacée, sans doublon |
| Question comparative ou mentionnant plusieurs philosophes | Recherche large sur tout le livre, sans filtre |
| Question dans une autre langue | Réponse en français |
| Message vide ou sans rapport (« salut ») | Réponse courte qui invite à poser une question de philosophie, sans recherche |
| Question hors sujet (rien de pertinent dans le livre) | Refus explicite |
| Question posée avant toute ingestion (base vide) | Refus, avec un message indiquant que le livre n'est pas chargé |
| Le fichier envoyé n'est pas un PDF exploitable | L'ingestion échoue et laisse une alerte dans l'historique |

## Gestion des erreurs
| Panne | Comportement attendu |
|---|---|
| Gemini indisponible ou quota dépassé pendant l'ingestion | Tout ou rien : l'ingestion est abandonnée et une alerte est laissée dans l'historique d'exécutions. La base n'est jamais à moitié remplie |
| Gemini en panne pendant une question | Message d'erreur clair dans le chat, sans réponse inventée |
| Redémarrage de l'instance | La base en mémoire est perdue. Il faut réingérer le livre (limite acceptée) |

## Contraintes
- **Droit d'auteur :** le PDF, le texte extrait et les chunks ne sont jamais commités ni exportés dans le dépôt GitHub public. Seul le workflow, sans données du livre, peut y aller.
- **Coût :** quota gratuit de Gemini, rien de payant en plus.
- **Temps de réponse :** moins de 30 secondes par réponse dans le chat.
- Le workflow n'est pas publié sans ton accord.

## Critères d'acceptation
- [ ] Étant donné le PDF valide, quand je l'envoie via le formulaire, alors la base contient des chunks avec philosophe, époque, numéro, citation, résumé et mots-clés.
- [ ] Étant donné la base chargée, quand je renvoie le même PDF, alors le nombre de chunks reste identique (pas de doublons).
- [ ] Étant donné la base chargée, quand je demande « Que veut dire "je pense, donc je suis" ? », alors la réponse cite Descartes avec la citation et son numéro.
- [ ] Étant donné la base chargée, quand je demande « Que dit Sartre sur les autres ? », alors la réponse s'appuie sur « L'enfer, c'est les autres ».
- [ ] Étant donné la base chargée, quand je demande « Quelle est la capitale de l'Australie ? », alors le système refuse de répondre.
- [ ] Étant donné la base chargée, quand je compare Descartes et Pascal, alors la réponse utilise des sources des deux auteurs.
- [ ] Étant donné une base vide, quand je pose une question, alors le système indique que le livre n'est pas chargé.
- [ ] Étant donné une panne simulée de Gemini pendant l'ingestion, alors la base reste vide (ou inchangée) et l'historique contient l'alerte.
- [ ] Toute réponse arrive en moins de 30 secondes.
- [ ] Le workflow montre visiblement les deux faces et leurs étapes (extraction, cleaning, chunking, augmentation, vectorisation ; input, sélection, recherche, reranking, génération).

## Points à décider
- **Skill d'interrogation depuis Claude Code** (webhook ou `n8ncli exec`) : écarté pour l'instant, à reprendre si tu veux une démo depuis le terminal.
- **Seuil de pertinence du reranking** : fixé à 6 après tests réels (questions du livre : meilleur score 8 à 10 ; hors sujet : 0).
- **Panne d'ingestion : testée.** Avec un modèle Gemini invalide, l'enrichissement échoue après 3 tentatives, l'exécution s'arrête sur ce nœud (alerte dans l'historique), l'assemblage et l'insertion ne s'exécutent pas, et la base reste intacte (même réponse à la même question avant et après).
- **Non testé en réel** : fichier non-PDF, panne de Gemini pendant une question.
- **Persistance** : la base en mémoire est perdue au redémarrage. Passer à une base persistante n'est pas dans le périmètre.
