part of 'cover_loader.dart';

extension _CoverDecode on CoverLoader {
  Future<_DecodedCover> _decodeAndCache(
    (ServerSession, String) key,
    Uint8List bytes,
  ) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    var reservation = 0;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      _scope.check();
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      _scope.check();
      final width = descriptor.width;
      final height = descriptor.height;
      if (width < 1 || height < 1) throw CoverFailure.nonImage;
      final pixels = decodedBudget ~/ 4;
      final scale = math.min(1.0, math.sqrt(pixels / (width * height)));
      var targetWidth = math.max(1, (width * scale).floor());
      var targetHeight = math.max(1, (height * scale).floor());
      if (targetWidth * targetHeight > pixels) {
        if (targetWidth >= targetHeight) {
          targetWidth = pixels ~/ targetHeight;
        } else {
          targetHeight = pixels ~/ targetWidth;
        }
      }
      final requiredBytes = targetWidth * targetHeight * 4;
      _reserve(requiredBytes);
      reservation = requiredBytes;
      codec = await descriptor.instantiateCodec(
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      _scope.check();
      image = (await (_decodeFrame?.call(codec) ?? codec.getNextFrame())).image;
      _scope.check();
      final entry = _DecodedCover(image);
      if (entry.bytes > reservation) throw CoverFailure.nonImage;
      _scope.publish(() {
        _decoded[key] = entry;
        _decodedBytes += entry.bytes;
      });
      image = null; // Cache owns this handle now.
      return entry;
    } on CoverFailure {
      rethrow;
    } on RequestCancelled {
      rethrow;
    } catch (_) {
      // Decoder exceptions can carry server bytes; only publish a fixed reason.
      throw CoverFailure.nonImage;
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
      if (reservation != 0) _reservedBytes -= reservation;
    }
  }
}
