---
name: doubt-driven-dev
description: Méthode de construction guidée par le doute pour workflows n8n, code ou automatisations : lister d'abord ce dont on n'est pas sûr, lever chaque doute par une preuve (test, doc, exécution réelle) avant d'avancer, construire par petites étapes vérifiées, et ne déclarer « terminé » que ce qui est prouvé. Utilise ce skill dès que l'utilisateur demande de construire, modifier ou déboguer quelque chose et veut que ce soit fiable, quand il dit « vérifie », « es-tu sûr ? », « teste avant », ou quand une tâche repose sur des API, des données ou des comportements qu'on ne connaît pas encore avec certitude.
---

# Doubt-driven development : ne rien affirmer sans preuve

L'erreur la plus coûteuse n'est pas de ne pas savoir, c'est de croire savoir. Une API qui renvoie un autre format que prévu, un paramètre au nom légèrement différent, un fuseau horaire par défaut : ce sont des suppositions qui passent inaperçues jusqu'au jour où le workflow tourne en production. Ce skill rend ces suppositions visibles et les transforme en faits vérifiés, une par une.

## Les trois statuts

Tout ce qui compte pour la réussite du travail a un statut :

- **Prouvé** : on a une preuve observable (sortie d'un test, données d'exécution, documentation officielle, fichier lu).
- **Supposé** : ça semble raisonnable, mais rien ne l'a confirmé.
- **Inconnu** : on ne sait pas.

« Ça devrait marcher » veut dire **Supposé**. Le mot « terminé » est réservé à ce qui est **Prouvé**.

## Déroulé

### 1. Registre des doutes (avant de construire)

Liste ce qui doit être vrai pour que le travail réussisse, et pour chaque point comment le vérifier au moindre coût :

```markdown
| # | Doute | Statut | Comment le lever |
|---|---|---|---|
| D1 | L'API Open Prices accepte une recherche par nom de produit | Supposé | Lire la doc + un appel de test |
| D2 | Le nœud Gmail accepte du HTML dans le message | Supposé | Consulter la définition du nœud |
| D3 | Le déclencheur utilise l'heure de Paris | Inconnu | Vérifier le réglage `timezone` du workflow |
```

Cherche en priorité les doutes sur : les formats de données, les noms exacts de paramètres, le comportement en cas d'erreur, le nombre d'éléments qui circulent, les dates et fuseaux horaires, les droits d'accès.

### 2. Lever les doutes, du moins cher au plus cher

Lire une doc ou un fichier coûte moins cher qu'un test, qui coûte moins cher qu'une reconstruction. Commence par les doutes dont dépend le reste : inutile de peaufiner l'e-mail si l'API de prix ne renvoie rien d'exploitable. Mets à jour le registre avec la preuve obtenue.

Un doute impossible à lever seul (choix métier, accès manquant) se pose à l'utilisateur, clairement, au lieu d'être tranché en silence.

### 3. Construire par petites étapes vérifiées

Avance d'un morceau testable à la fois et vérifie-le avant de passer au suivant. Dans n8n : teste avec des données simulées (pin data), puis lis les **données d'exécution** de chaque nœud. Un statut « success » ne suffit pas : un workflow peut réussir en produisant un résultat faux ou vide. Vérifie le contenu, par exemple en recalculant un total à la main.

Teste aussi les chemins d'erreur : liste vide, service en panne, envoi raté. Ce sont eux qui sont le moins souvent testés et qui cassent en production.

### 4. S'arrêter quand ça surprend

Si un résultat ne correspond pas à ce que tu attendais, même s'il « a l'air correct », arrête-toi et comprends pourquoi avant de continuer. Une surprise est le signe qu'une supposition était fausse : ajoute-la au registre.

### 5. Rapport final honnête

```markdown
## Ce qui est prouvé
- <comportement> — preuve : <test, exécution n°, calcul>

## Ce qui n'est pas testé
- <comportement> — pourquoi : <raison> — risque : <ce qui pourrait arriver>

## Doutes restants
- <doute> — qui peut trancher / comment le lever
```

Ne présente jamais un point non testé comme acquis. Si l'utilisateur demande « ça marche ? », réponds avec ce qui est prouvé et ce qui ne l'est pas, pas avec un « oui » global.
