import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'API_KEY', obfuscate: true)
  static final mbgKey = _Env.mbgKey;

  @EnviedField(varName: 'API_URL')
  static const mbgUrl = _Env.mbgUrl;
}
