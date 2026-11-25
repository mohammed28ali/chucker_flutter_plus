# Chucker Flutter Plus example

The playground calls JSONPlaceholder. Dio and `package:http` traffic appears
in the inspector, and the terminal shows request summaries from those clients
and Chopper. Trigger the 404 to try the error-only in-app banner, then tap its
Details button to open that transaction.

From this directory, fetch dependencies and run on a configured target.

```sh
flutter pub get
flutter run -d linux
```

For a checkout without the native runner for your target, generate it from
this directory, for example `flutter create --platforms=android .`. Linux
requires the GTK 3 development packages. Follow the
[notification plugin's platform setup](https://pub.dev/packages/flutter_local_notifications/versions/23.0.3#android-setup)
for Android Gradle and Apple delegate requirements when testing system
notifications. On Android, also include the Internet permission in the main
manifest for release or profile builds.

System notifications are enabled in the demo. To let it prompt for permission
on a supported platform, run with
`--dart-define=CHUCKER_REQUEST_PERMISSION=true`. Background the app during an
in-flight failing request to exercise system delivery.

[main.dart](lib/main.dart) initializes `Inspector` and wires its navigator key.
[dependency_injection.dart](lib/core/di/dependency_injection.dart) shows how the
clients share a console logger and attach capture independently.
