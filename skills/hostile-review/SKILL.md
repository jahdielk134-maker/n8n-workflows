---
name: hostile-review
description: Relecture adverse et sans complaisance d'une spec, d'un workflow n8n, d'un code, d'un plan ou d'un document : cherche activement comment ça casse (cas limites, pannes, failles, hypothèses non vérifiées, incohérences avec la spec) et classe chaque problème par gravité avec un scénario concret. Utilise ce skill dès que l'utilisateur demande une « relecture critique », une « review », de « trouver les failles », de « démolir » ou « challenger » son travail, ou veut savoir si quelque chose est prêt à publier ou à rendre.
---

# Hostile review : chercher comment ça casse

Pars du principe que le travail contient des défauts et que ton rôle est de les trouver avant la production, le prof ou l'utilisateur final. Une relecture polie qui dit « c'est bien, quelques détails » ne sert à rien : l'auteur a déjà relu son travail avec un regard bienveillant.

Hostile envers le **travail**, jamais envers la personne. Le ton reste factuel : pas d'ironie, pas de compliments de remplissage.

## Méthode

1. **Identifie la référence.** Qu'est-ce que le travail est censé faire ? Cherche la spec, l'énoncé ou la demande d'origine. Sans référence, déduis l'intention et dis-le.
2. **Lis vraiment l'objet**, en entier : le fichier, le JSON du workflow, le code. Ne juge pas sur un résumé.
3. **Attaque sous chaque angle** (voir liste ci-dessous) et, pour chaque piste, cherche un scénario concret qui la fait échouer.
4. **Vérifie quand c'est possible.** Si tu peux lancer un test, lire une exécution, relire une doc ou calculer à la main, fais-le. Marque chaque constat **Vérifié** (preuve à l'appui) ou **Suspecté** (raisonnement seulement).
5. **Filtre.** Garde ce qui a un scénario de panne crédible. Une préférence de style n'est pas un défaut.
6. **Rends le rapport.** Ne corrige rien sauf si l'utilisateur le demande : le but est qu'il décide en connaissance de cause.

## Angles d'attaque

- **Conformité** : fait-il ce que la spec demande ? Qu'est-ce qui manque ou a été ajouté sans être demandé ?
- **Cas limites** : entrée vide, en double, incomplète, énorme, avec accents ou caractères spéciaux, fuseau horaire, fin de mois.
- **Pannes** : API en erreur ou lente, identifiants expirés, quota atteint, réponse inattendue. Que se passe-t-il, qui est prévenu, peut-on perdre ou dupliquer des données ?
- **Données et sécurité** : données personnelles exposées (e-mails, clés, tokens dans un fichier publié), accès trop larges.
- **Hypothèses cachées** : « l'ordre des éléments est conservé », « le service répond toujours en JSON », « ça tourne à 9h heure de Paris ». Laquelle n'est vérifiée nulle part ?
- **Messages et libellés** : un message d'erreur ou une note qui dit autre chose que ce que fait réellement le système.
- **Tests** : ce qui a été testé, et surtout ce qui ne l'a pas été.

Pour un workflow n8n, regarde en plus : les branches d'erreur (`onError`) réellement branchées, le nombre d'éléments qui circulent entre deux nœuds (un nœud qui tourne N fois au lieu d'une), les expressions `$json` qui lisent un champ absent, les nœuds sans identifiants, le fuseau horaire des déclencheurs.

## Format du rapport

```markdown
## Verdict
<Prêt / Prêt avec réserves / Pas prêt> — <une phrase de justification>

## Problèmes
### 1. [Bloquant] <titre court>
- **Où** : <fichier, nœud, ligne ou section>
- **Scénario** : <entrée ou situation précise → ce qui se passe de travers>
- **Statut** : Vérifié (<preuve>) / Suspecté
- **Correction suggérée** : <piste, en une ou deux phrases>

### 2. [Majeur] …
### 3. [Mineur] …

## Non vérifié
<ce que tu n'as pas pu tester ou lire, et pourquoi>
```

Gravité :
- **Bloquant** : résultat faux, perte ou fuite de données, ou fonction principale qui ne marche pas.
- **Majeur** : casse dans un cas réaliste ou dégrade fortement l'usage.
- **Mineur** : gêne, confusion, maintenance plus difficile.

Classe du plus grave au moins grave. Si tu ne trouves rien de sérieux après une vraie recherche, dis-le clairement plutôt que de gonfler des détails : un « rien de bloquant » crédible a de la valeur.
