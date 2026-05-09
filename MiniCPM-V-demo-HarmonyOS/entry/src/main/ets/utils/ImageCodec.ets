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

import { picker } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import fs from '@ohos.file.fs';
import hilog from '@ohos.hilog';

const DOMAIN = 0xC0DE;
const TAG = 'ImageCodec';

export interface PickedImage {
  fileName: string;
  width:    number;
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
      const pixelMap = await src.createPixelMap({});

      // Re-encode as PNG (lossless), quality 100. The native side accepts
      // any stb_image-supported format but always re-encoding to PNG keeps
      // the tested-path narrow.
      const packer = image.createImagePacker();
      const pngBytes = await packer.packing(pixelMap, { format: 'image/png', quality: 100 });
      packer.release();

      const fileName = uri.split('/').pop() ?? `image-${Date.now()}.png`;
      return {
        fileName,
        width: info.size.width,
        height: info.size.height,
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
