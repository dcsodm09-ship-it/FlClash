import 'package:fl_clash/hgfast/repository/hgfast_repository_impl.dart';
import 'package:fl_clash/hgfast/repository/repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part '../generated/hgfast/repository.g.dart';

@Riverpod(keepAlive: true)
HgfastRepository hgfastRepository(Ref ref) {
  final repository = HgfastRepositoryImpl();
  ref.onDispose(repository.dispose);
  return repository;
}
