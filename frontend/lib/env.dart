import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'API_KEY', obfuscate: true)
  static final String mbgKey = _Env.mbgKey;

  @EnviedField(varName: 'API_URL')
  static const String mbgUrl = _Env.mbgUrl;

  @EnviedField(varName: 'VERSION')
  static const String version = _Env.version;
}
