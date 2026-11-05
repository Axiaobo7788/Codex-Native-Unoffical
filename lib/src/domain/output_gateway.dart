import 'output_models.dart';

abstract interface class OutputGateway {
  Future<OutputDescriptor> statOutput(String reference);
  Future<OutputChunk> readOutputRange({
    required String reference,
    required int offset,
    required int length,
  });
  Future<OutputChunk> readOutputTail({
    required String reference,
    required int length,
  });
}
