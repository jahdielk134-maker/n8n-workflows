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
