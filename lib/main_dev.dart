import 'environment/environment.dart';
import 'environment/environment_type.dart';

Future<void> main() async {
  await Environment.init(EnvironmentType.dev).run();
}
