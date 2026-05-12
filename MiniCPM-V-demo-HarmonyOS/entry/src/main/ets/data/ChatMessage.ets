// Direct port of MiniCPM-V-demo-Android/.../ChatMessage.kt.
//
// Three message variants are merged into a single tagged class because
// LazyForEach prefers a stable type. The discriminator field `kind`
// tells the renderer which item template to use; per-kind fields are
// nullable but only populated for the matching kind.
//
// `imageData` holds the decoded PNG bytes used for the `prefillImage`
// native call. We hold it on the message until prefill completes so the
// progress indicator has somewhere to attach.

import { image } from '@kit.ImageKit';

export type ChatMessageKind = 'welcome' | 'user' | 'ai';

@Observed
export class ChatMessage {
  id: number;
  kind: ChatMessageKind;
  text: string;

  // user-specific
  imagePixelMap: image.PixelMap | null;
  imageInfo: string | null;
  isPrefilling: boolean;
  // When true, [imagePixelMap] is the first frame of a video clip and
  // the cell overlays a play-arrow badge.  Mirrors Android demo's
  // ChatMessage.UserMessage.isVideo.
  isVideo: boolean;

  // ai-specific
  isGenerating: boolean;

  constructor(id: number, kind: ChatMessageKind) {
    this.id = id;
    this.kind = kind;
    this.text = '';
    this.imagePixelMap = null;
    this.imageInfo = null;
    this.isPrefilling = false;
    this.isVideo = false;
    this.isGenerating = false;
  }

  static welcome(): ChatMessage {
    return new ChatMessage(0, 'welcome');
  }

  static user(id: number, text: string,
              pixelMap: image.PixelMap | null = null,
              imageInfo: string | null = null,
              isPrefilling: boolean = false,
              isVideo: boolean = false): ChatMessage {
    const m = new ChatMessage(id, 'user');
    m.text = text;
    m.imagePixelMap = pixelMap;
    m.imageInfo = imageInfo;
    m.isPrefilling = isPrefilling;
    m.isVideo = isVideo;
    return m;
  }

  static ai(id: number, text: string = '', isGenerating: boolean = false): ChatMessage {
    const m = new ChatMessage(id, 'ai');
    m.text = text;
    m.isGenerating = isGenerating;
    return m;
  }
}
