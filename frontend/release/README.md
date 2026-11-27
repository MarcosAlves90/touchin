# Release catalog

Arquivo de referência para versão e publicação do app Flutter, hoje focado em Android.

## Regras

- `frontend/pubspec.yaml` continua sendo fonte da versão técnica do build (`x.y.z+build`)
- `frontend/release/catalog.json` define nome de linha e regras de publicação
- `releaseName` segue o padrão `Bunchin {x.y.z}-{lineNameSlug}`
- o `x` de `x.y.z` define a linha da release
- `1.y.z` pertence a `Woodpecker`
- `2.y.z` pertence a `Atlas`
- novas plataformas entram em `platforms.<nome>` sem quebrar o formato atual

## Android

Android usa `versionName` e `versionCode` vindos do Flutter, e release signing fica isolado em:

- `frontend/android/key.properties` para segredos locais
- `frontend/android/key.properties.example` como template versionado
- `frontend/android/app/build.gradle.kts` para wiring do release build

## Fluxo recomendado

1. Atualize `frontend/pubspec.yaml` com a nova versão semântica.
2. Se a versão cruzar de linha major, ajuste a linha correspondente em `frontend/release/catalog.json`.
3. Configure `frontend/android/key.properties` a partir do template.
4. Rode `dart run scripts/release_info.dart validate` dentro de `frontend/`.
5. Publique com `flutter build appbundle --release`.

## Automação GitHub

O ID de instalação continua sendo `com.bunchin.app` para atualizar o APK já publicado.
O endpoint oficial é passado por `API_BASE_URL` no build Android; o app em
desenvolvimento mantém o padrão local. Use `release/notes/vX.Y.Z.md` para notas
específicas de uma versão (relativo a `frontend/`).

Pushes em branches `release/**` acionam `.github/workflows/android-release.yml`.

O workflow:

- valida `frontend/release/catalog.json`
- testa a inicialização com modo normal e roda a suíte Flutter com a prévia habilitada, exceto os goldens do job canônico
- monta `build/app/outputs/bundle/release/app-release.aab`
- monta `build/app/outputs/flutter-apk/app-release.apk`
- verifica versão, pacote, permissões, API, assinatura do AAB e certificado do APK em relação à release anterior
- cria a tag `vX.Y.Z`
- publica uma GitHub Release pre-release com o nome completo da versão

Secrets necessários:

- `ANDROID_KEYSTORE_BASE64`: keystore Android em base64
- `ANDROID_KEYSTORE_PASSWORD`: senha do keystore
- `ANDROID_KEY_PASSWORD`: senha da chave
- `ANDROID_KEY_ALIAS`: alias da chave

Se a tag já existir, o workflow falha. Nesse caso, incremente `version:` em `frontend/pubspec.yaml`.
