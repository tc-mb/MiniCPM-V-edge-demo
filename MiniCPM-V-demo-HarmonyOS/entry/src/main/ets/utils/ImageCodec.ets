// Image picker + decoder helpers. Mirrors the Android demo's
// MainActivity.handleSelectedImage flow (read URI -> decode bitmap ->
// re-encode as PNG bytes -> hand to native prefillImage).
//
// On HarmonyOS we use:
//   * @ohos.file.picker.PhotoViewPicker     -> system gallery
//   * @ohos.multimedia.image.ImageSource     -> decode any of jpg/png/heic
//   * imagePackerApi.packing                 -> re-encode as PNG so the
//                                               C++ side (stb_image) only
//                                               has to handle one format
//
// Down-sampling policy (TODO: revisit when we re-enable multi-slice prefill):
// the native side currently sets `image_max_slice_nums = 1`, so mtmd / clip
// will always squeeze the whole image into a single ~448 px overview tile
// regardless of input resolution. Sending the original 4000x3000 picture is
// therefore pure waste -- it bloats the NAPI ArrayBuffer copy, makes PNG
// re-encoding multi-second on a low-end CPU, and the model sees the exact
// same downscaled tile as if we'd sent a 1024-edge image. We cap the long
// edge at 1024 px before PNG encoding to keep memory/IPC cheap; once we
// (eventually) re-enable multi-slice prefill on Android / HarmonyOS this
// cap should be raised or removed.

import { picker } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import fs from '@ohos.file.fs';
import hilog from '@ohos.hilog';

const DOMAIN = 0xC0DE;
const TAG = 'ImageCodec';

// Long-edge cap fed into the native prefill path. See file header.
const TARGET_LONG_EDGE = 1024;

export interface PickedImage {
  fileName: string;
  width:    number;     // dimensions actually fed to native (post-downsample)
  height:   number;
  pngBytes: ArrayBuffer;
  pixelMap: image.PixelMap;
}

// Open the system photo picker, let the user pick exactly one image,
// then decode + re-encode as PNG. Returns null if the user cancels.
export async function pickAndDecodeImage(): Promise<PickedImage | null> {
  const photoPicker = new picker.PhotoViewPicker();
  const opts = new picker.PhotoSelectOptions();
  opts.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
  opts.maxSelectNumber = 1;

  let uris: string[];
  try {
    const res = await photoPicker.select(opts);
    uris = res.photoUris;
  } catch (e) {
    hilog.warn(DOMAIN, TAG, 'photoPicker cancelled or failed: %{public}s', `${e}`);
    return null;
  }
  if (!uris || uris.length === 0) {
    return null;
  }
  const uri = uris[0];

  const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
  try {
    const src = image.createImageSource(file.fd);
    try {
      const info = await src.getImageInfo();
      const origW = info.size.width;
      const origH = info.size.height;
      const longEdge = Math.max(origW, origH);

      // Step 1: pick a sampleSize (1/2/4/8) to keep peak decode memory low.
      // sampleSize is the cheapest way to downsample because it happens
      // during decode, before we ever materialise the full RGBA buffer.
      let sampleSize = 1;
      while (sampleSize < 8 && longEdge / (sampleSize * 2) >= TARGET_LONG_EDGE) {
        sampleSize *= 2;
      }
      const decodeOpts: image.DecodingOptions = sampleSize > 1
        ? { sampleSize }
        : {};
      const pixelMap = await src.createPixelMap(decodeOpts);

      // Step 2: sampleSize is geometric, so the result might still be a bit
      // larger than TARGET_LONG_EDGE (e.g. a 2400 px image with sampleSize=2
      // lands at 1200 px). Snap to the cap with PixelMap.scale().
      const sampledLongEdge = longEdge / sampleSize;
      if (sampledLongEdge > TARGET_LONG_EDGE) {
        const ratio = TARGET_LONG_EDGE / sampledLongEdge;
        await pixelMap.scale(ratio, ratio);
      }

      // After the optional scale, `pixelMap.getImageInfo()` reflects the new
      // dimensions, which is what the model actually sees.
      const finalInfo = await pixelMap.getImageInfo();
      hilog.info(DOMAIN, TAG,
        'image downsampled: %{public}dx%{public}d -> %{public}dx%{public}d (sampleSize=%{public}d)',
        origW, origH, finalInfo.size.width, finalInfo.size.height, sampleSize);

      // Re-encode as PNG (lossless), quality 100. The native side accepts
      // any stb_image-supported format but always re-encoding to PNG keeps
      // the tested-path narrow.
      const packer = image.createImagePacker();
      const pngBytes = await packer.packing(pixelMap, { format: 'image/png', quality: 100 });
      packer.release();

      const fileName = uri.split('/').pop() ?? `image-${Date.now()}.png`;
      return {
        fileName,
        width: finalInfo.size.width,
        height: finalInfo.size.height,
        pngBytes,
        pixelMap,
      };
    } finally {
      await src.release();
    }
  } finally {
    fs.closeSync(file);
  }
}

export function imageInfoString(img: PickedImage): string {
  const sizeKb = Math.floor(img.pngBytes.byteLength / 1024);
  return `${img.width} x ${img.height} (${sizeKb} KB)`;
}
