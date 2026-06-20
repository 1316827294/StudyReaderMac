# StudyReaderMac

[English](README.md) | [简体中文](README-zh.md) | [日本語](README-ja.md) | [한국어](README-ko.md) | [Español](README-es.md) | [Français](README-fr.md) | [Deutsch](README-de.md)

StudyReaderMac est un outil d'étude natif pour macOS conçu spécifiquement pour les étudiants et les apprenants. Il vous permet d'étudier facilement des manuels PDF ou des livres EPUB sans DRM sur votre Mac sans avoir besoin de livres papier physiques.

## Pourquoi StudyReaderMac ?
L'étude traditionnelle vous oblige souvent à jongler entre des livres physiques, des cahiers et des documents de référence. StudyReaderMac simplifie cela en fournissant une interface à double panneau :
- **Panneau gauche (Lecture) :** Lisez directement vos manuels PDF ou EPUB.
- **Panneau droit (Réponse) :** Rédigez vos réponses, notes ou solutions.
- **Vérification de l'IA :** Une fois que vous avez répondu à une question, l'application capture votre vue de lecture actuelle et votre réponse, en l'envoyant à OpenAI (ou à des API compatibles comme DeepSeek/Ollama) pour vérifier votre exactitude et fournir des commentaires instantanés.

Cela rend l'étude et la validation de vos réponses fluides, efficaces et entièrement sans papier, ce qui est parfait pour les étudiants préparant des examens ou pour quiconque apprend de nouveaux sujets.

## Fonctionnalités
- **Étude sans papier :** Abandonnez les lourds livres papier et les cahiers. Lisez, répondez et vérifiez tout au sein d'une seule application.
- **Commentaires instantanés de l'IA :** Obtenez des corrections et des explications immédiates de la part de l'IA pour vos réponses écrites, basées sur le contenu visible du manuel.
- **Défilement continu et synchronisation :** Le panneau de lecture et votre feuille de réponses se synchronisent automatiquement pour garder votre place.
- **Plusieurs fournisseurs d'API :** Préconfiguré avec OpenAI, DeepSeek et Ollama, ou utilisez votre propre endpoint personnalisé.
- **Prise en charge multilingue :** Interface disponible en anglais, chinois, japonais, coréen, espagnol, français et allemand.

## Guide de configuration de l'API
StudyReaderMac vous permet d'utiliser divers modèles d'IA pour vérifier vos réponses. Allez dans les **Réglages** pour configurer votre fournisseur d'API préféré :

- **OpenAI:** 
  - Sélectionnez "OpenAI" dans la liste des fournisseurs d'API.
  - Entrez votre clé API OpenAI.
  - Le modèle par défaut est `gpt-5.5`.
- **DeepSeek:**
  - Sélectionnez "DeepSeek".
  - Entrez votre clé API DeepSeek.
  - Le modèle par défaut est `deepseek-v4-flash`.
- **Ollama (Modèles locaux):**
  - Assurez-vous que Ollama est en cours d'exécution localement.
  - Sélectionnez "Ollama". L'adresse de l'API se remplira automatiquement avec `http://localhost:11434/v1/chat/completions`.
  - Le modèle par défaut est `llama3` (assurez-vous d'avoir exécuté `ollama run llama3`).
  - **Note:** L'application nécessite qu'une clé API soit renseignée. Pour Ollama, entrez simplement un texte factice comme `ollama`.
- **Personnalisé / LM Studio:**
  - Sélectionnez "Personnalisé".
  - Entrez l'URL de votre endpoint compatible (par exemple, `http://localhost:1234/v1/chat/completions` pour LM Studio).
  - Entrez le nom exact du modèle.
  - Entrez votre clé API (ou une clé factice s'il s'agit d'un modèle local sans authentification).

## Lancer

```bash
swift run StudyReaderMac
```

## Empaqueter comme application macOS

```bash
sh Scripts/package-app.sh
open dist/StudyReaderMac.app
```

## Notes

- L'application ne capture pas les fenêtres des autres applications et ne nécessite donc pas l'autorisation d'"Enregistrement de l'écran".
- Les fichiers Kindle/Apple Books protégés par DRM ne sont pas pris en charge.
- Le modèle par défaut est `gpt-5.5` (lors de l'utilisation d'OpenAI) ; modifiez-le dans les Réglages si votre compte API nécessite un autre modèle.
