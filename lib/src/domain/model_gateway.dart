import 'model_models.dart';

abstract interface class ModelGateway {
  Future<ModelPage> listModels(ModelListQuery query);
}
