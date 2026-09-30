# n8n workflows

Mes workflows [n8n](https://n8n.io), exportés en JSON.

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
