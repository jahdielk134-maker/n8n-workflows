---
name: interview
description: Transforme une idée floue en spécification complète en interviewant l'utilisateur, une question à la fois (objectif, déclencheur, entrées, sorties, outils, règles, cas limites, erreurs, contraintes, critères de réussite), puis rédige la spec. Utilise ce skill dès que l'utilisateur veut « faire les specs », « cadrer », « préciser » ou « réfléchir à » un workflow, une automatisation, un agent ou une appli avant de la construire, ou quand sa demande est trop vague pour être construite sans deviner, même s'il ne dit pas « interview ».
---

# Interview : de l'idée floue à la spec

Le but est d'obtenir une spec assez précise pour qu'on puisse construire sans deviner. La spec décrit **le quoi, pas le comment** : ce que le système doit faire et dans quelles conditions, pas quels nœuds ou quel code utiliser. Les choix techniques viennent après, à l'étape d'architecture.

Pourquoi une interview plutôt qu'un formulaire : l'utilisateur ne sait souvent pas ce qu'il n'a pas précisé. Une question à la fois, posée au bon moment, fait émerger les cas limites qu'une liste de 15 questions d'un coup ferait survoler.

## Déroulé

1. **Reformule l'idée en une phrase** et fais-la valider. Si la conversation contient déjà des éléments (fichiers, messages précédents), pars de là au lieu de reposer les questions.
2. **Pose une seule question par message.** Propose 2 à 4 réponses possibles quand c'est utile (l'utilisateur choisit ou corrige) et dis pourquoi la question compte si ce n'est pas évident.
3. **Suis la grille ci-dessous**, dans l'ordre qui a du sens pour le projet. Saute ce qui est déjà connu ou sans objet.
4. **Creuse les réponses vagues.** « Quand il y a un problème » → quel problème, qui est prévenu, comment ? « Souvent » → combien de fois ? Un exemple concret vaut mieux qu'une définition.
5. **Fais un point d'étape toutes les 4 à 5 questions** : résume en quelques puces ce qui est acquis, pour que l'utilisateur corrige tôt.
6. **Arrête-toi** quand la grille est couverte ou quand l'utilisateur veut s'arrêter. Ce qui reste ouvert va dans « Points à décider », jamais inventé.
7. **Rédige la spec** avec le modèle ci-dessous et demande une validation.

## Grille de couverture

| Thème | Ce qu'on cherche à savoir |
|---|---|
| Objectif | Quel problème, pour qui, et à quoi on voit que c'est réussi |
| Déclencheur | Qu'est-ce qui lance le processus : horaire, événement, action manuelle |
| Entrées | Quelles données, d'où, sous quelle forme, qui les remplit |
| Sorties | Ce qui est produit, pour qui, où, sous quel format |
| Écosystème | Outils et comptes existants (Gmail, Sheets, Notion…), accès disponibles |
| Règles métier | Calculs, tris, fusions, priorités, ce qui est interdit |
| Cas limites | Données vides, en double, incomplètes, inattendues, très volumineuses |
| Erreurs | Service en panne, envoi raté : qui est prévenu, on réessaie, on abandonne ? |
| Contraintes | Délais, fréquence, coût, confidentialité, données personnelles |
| Critères d'acceptation | Des tests concrets : « avec telle entrée, j'attends telle sortie » |

Les cas limites et les erreurs sont les thèmes que les gens oublient le plus. Ne les saute pas parce que l'utilisateur semble pressé ; pose au moins une question sur chacun.

## Modèle de spec

```markdown
# Spec : <nom du projet>

## Objectif
<1 à 3 phrases : quel problème, pour qui>

## Déclencheur
## Entrées
## Sorties
## Écosystème
## Règles métier
## Cas limites
| Situation | Comportement attendu |
|---|---|

## Gestion des erreurs
| Panne | Comportement attendu |
|---|---|

## Contraintes
## Critères d'acceptation
- [ ] Étant donné <situation>, quand <action>, alors <résultat vérifiable>

## Points à décider
<questions restées ouvertes, avec qui doit trancher>
```

## Exemple de bonne question

> Si ta liste de courses contient deux fois « Spaghetti », que doit faire le workflow ?
> 1. Fusionner et additionner les quantités (Spaghetti ×3)
> 2. Garder les deux lignes
> 3. Garder seulement la première
>
> Je pose la question parce que ça change le total estimé.

À éviter : « Peux-tu me décrire toutes tes règles de gestion ? » (trop large, l'utilisateur oubliera la moitié).
