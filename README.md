# n8n workflows

Mes workflows [n8n](https://n8n.io), exportés en JSON, et les skills Claude Code qui m'aident à les concevoir.

## Skills Claude Code

| Skill | Rôle |
|---|---|
| [`interview`](skills/interview/SKILL.md) | Transforme une idée floue en spec complète, une question à la fois (le quoi, pas le comment). |
| [`hostile-review`](skills/hostile-review/SKILL.md) | Relecture adverse : cherche comment le travail casse et classe chaque problème par gravité. |
| [`doubt-driven-dev`](skills/doubt-driven-dev/SKILL.md) | Construire en listant ses doutes, en les levant par des preuves et en ne déclarant fini que ce qui est prouvé. |

Enchaînement typique : `interview` → spec, `doubt-driven-dev` → construction, `hostile-review` → relecture avant publication.

**Installation :** copier chaque dossier de `skills/` dans `~/.claude/skills/`, puis les appeler avec `/interview`, `/hostile-review` ou `/doubt-driven-dev` (Claude peut aussi les utiliser de lui-même quand la demande s'y prête).

## Liste de courses hebdomadaire par e-mail

[`liste-de-courses/workflow.json`](liste-de-courses/workflow.json)

Chaque samedi à 9h, le workflow :

1. récupère la liste de courses (liste d'exemple pour l'instant) ;
2. fusionne les doublons et marque les articles sans quantité « à vérifier » ;
3. cherche un prix indicatif pour chaque article via l'API [Open Prices](https://prices.openfoodfacts.org) ;
4. envoie la liste et le coût total estimé par Gmail.

Gestion des erreurs :

- liste vide → e-mail de rappel ;
- Open Prices indisponible → 3 essais, puis e-mail d'alerte et arrêt ;
- échec de l'envoi Gmail → nouvel essai toutes les heures jusqu'à midi.

### Importer le workflow

1. Dans n8n : **Create workflow** → menu **⋯** → **Import from File** → choisir `workflow.json`.
2. Ouvrir les 3 nœuds Gmail, sélectionner votre compte Gmail et remplacer `ton-adresse@example.com` par votre adresse.
3. Cliquer sur **Tester maintenant**, puis **Execute workflow**.

## RAG sur un livre de philosophie (exercice de cours)

[`rag-philosophie/workflow.json`](rag-philosophie/workflow.json) · [`rag-philosophie/spec.md`](rag-philosophie/spec.md) (la spec écrite avec le skill `interview`)

Un RAG sur *Les 100 citations de la philosophie*, construit pour montrer les deux faces d'un RAG et chacune de leurs étapes.

**Ingestion** (formulaire, envoi du PDF) :

1. extraction du texte du PDF ;
2. cleaning (retire couverture, introduction et mentions parasites) et chunking (un chunk par paragraphe de commentaire) ;
3. augmentation : métadonnées (philosophe, époque, numéro de la citation) et enrichissement par Gemini (résumé, mots-clés, questions types) ;
4. vectorisation dans un Simple Vector Store, vidé avant chaque ingestion. Si l'enrichissement échoue, l'ingestion s'arrête avant l'insertion et la base reste intacte.

**Answering** (chat) :

1. sélection : Gemini repère salutation ou question, philosophe, époque, et reformule la question ;
2. recherche des 40 passages les plus proches, puis filtre par métadonnées ;
3. reranking par Gemini (notes de 0 à 10), garde les 5 meilleurs au-dessus du seuil de 6 (et le meilleur passage de chaque philosophe cité pour une comparaison) ;
4. génération en français avec la citation, le philosophe et son numéro ; refus explicite si rien de pertinent n'est trouvé dans le livre.

### Importer le workflow

1. Dans n8n : **Create workflow** → menu **⋯** → **Import from File** → choisir `workflow.json`.
2. Attacher des credentials Google Gemini aux 4 nœuds « Gemini Flash » et OpenAI aux 2 nœuds « Embeddings OpenAI » (les embeddings d'une question ne sont pas pris en charge avec Gemini via les crédits Gateway de n8n).
3. Dans le nœud **Cleaning**, renseigner `PIED_DE_PAGE` (texte du pied de page répété dans votre PDF) et `LIGNES_A_RETIRER` (lignes parasites à supprimer). Cleaning et Chunking sont écrits pour la structure de ce livre : 100 entrées « citation, philosophe (dates), commentaire » précédées d'une table des matières.
4. Lancer le formulaire avec votre PDF (environ 6 à 8 minutes), puis poser vos questions dans le chat.

La base est en mémoire : elle est perdue si l'instance n8n redémarre. Le livre est protégé par le droit d'auteur : ce dépôt ne contient aucune donnée du livre, uniquement le workflow.
