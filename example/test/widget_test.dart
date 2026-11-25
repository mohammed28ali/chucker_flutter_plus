import 'package:chucker_flutter_plus_example/domain/entities/post.dart';
import 'package:chucker_flutter_plus_example/domain/repositories/posts_repository.dart';
import 'package:chucker_flutter_plus_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dashboard loads posts from the repository', (tester) async {
    final repository = _FakePostsRepository();
    await tester.pumpWidget(ChuckerExampleApp(repository: repository));

    expect(find.text('Chucker Plus'), findsOneWidget);
    expect(find.text('Try the inspector'), findsOneWidget);

    await tester.tap(find.text('Fetch recent posts'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.requestedLimit, 8);
    expect(find.text('Posts loaded · GET 200'), findsOneWidget);
    expect(find.text('A test post'), findsOneWidget);
  });
}

class _FakePostsRepository implements PostsRepository {
  int? requestedLimit;

  static const _post = Post(
    id: 1,
    userId: 1,
    title: 'A test post',
    body: 'Returned from the fake repository.',
  );

  @override
  Future<List<Post>> getPosts({required int limit}) async {
    requestedLimit = limit;
    return const [_post];
  }

  @override
  Future<Post> getPost(int id) async => _post;

  @override
  Future<Post> createPost({
    required String title,
    required String body,
    required int userId,
  }) async => _post;

  @override
  Future<void> getMissingPost() async {}
}
