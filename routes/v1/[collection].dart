import 'package:dart_frog/dart_frog.dart';

import '../../constants/standard_responses.dart';
import '../../extensions/e_request_context.dart';
import '../../mixin/mix_mongo_storage_model.dart';
import '../../routes_handlers/v1/handle_delete.dart';
import '../../routes_handlers/v1/handle_get.dart';
import '../../routes_handlers/v1/handle_patch.dart';
import '../../routes_handlers/v1/handle_post.dart';
import '../../storage_models/m_animal.dart';
import '../../storage_models/m_group.dart';
import '../../storage_models/m_judging_criteria.dart';
import '../../storage_models/m_judging_result.dart';
import '../../storage_models/m_leaderboard.dart';
import '../../storage_models/m_round2_group.dart';
import '../../storage_models/m_round_config.dart';
import '../../storage_models/m_user.dart';

/// LIST OF STORAGE MODELS TO AUTOMATICALLY APPLY CRUD APIS TO.
///
/// To expose a new collection at `/v1/{collectionId}`:
/// 1. Create a model in `storage_models/` extending `MongoModel` or
///    `MongoFlagDeleteModel` with a static `MongoStorageModel storage` field.
/// 2. Add `MyModel.storage` to this list.
final List<MongoStorageModel> collectionModels = [
  UserModel.storage,
  AnimalModel.storage,
  GroupModel.storage,
  Round2GroupModel.storage,
  JudgingCriteriaModel.storage,
  JudgingResultModel.storage,
  RoundConfigModel.storage,
  LeaderboardModel.storage,
];

Future<Response> onRequest(RequestContext context, String collection) async {
  final MongoStorageModel? storage =
      collectionModels.where((e) => e.collectionId == collection).firstOrNull;

  if (storage == null) return StandardResponses.noCollectionFound();

  return context.forHttpMethod(
    getResponse: () => handleGet(
      context,
      storage,
      Map.from(context.request.uri.queryParameters),
    ),
    postResponse: () => handlePost(context, storage),
    patchResponse: () => handlePatch(context, storage),
    delete: () => handleDelete(context, storage),
  );
}
