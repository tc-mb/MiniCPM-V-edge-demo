// Direct port of MiniCPM-V-demo-Android/.../LlamaEngine.kt.
//
// Mapping notes:
//
//   Kotlin                                    -> ArkTS
//   ──────────────────────────────────────────────────────────────────────────
//   companion object + @Volatile instance     -> static getInstance()
//   Dispatchers.IO.limitedParallelism(1)      -> private serial Promise chain
//   MutableStateFlow<LlamaState>              -> @Observed wrapper + listeners
//   Flow<String> sendUserPrompt(...)          -> AsyncIterable<string>
//                                                (driven by streamUserPrompt
//                                                 native callbacks)
//   SharedPreferences                         -> @ohos.data.preferences
//   File / FileInputStream                    -> @ohos.file.fs
//
// The state machine, native call sequencing and per-turn token budget are
// preserved exactly so the engine can be swapped for the Android one without
// any business-logic-level surprises.

import nativeEngine from 'libentry.so';
import common from '@ohos.app.ability.common';
import dataPreferences from '@ohos.data.preferences';
import fs from '@ohos.file.fs';
import { BusinessError } from '@ohos.base';
import hilog from '@ohos.hilog';

import { LlamaState } from './LlamaState';
import {
  ModelInfo,
  AVAILABLE_MODELS,
  DEFAULT_MODEL,
  LEGACY_FILE_RENAMES,
  findModelById,
} from './ModelInfo';
import { downloadModelsForSelected, ProgressListener } from '../utils/DownloadManager';

const TAG = 'LlamaEngine';
const DOMAIN = 0xC0DE;

const PREFS_NAME = 'model_prefs';
const KEY_SELECTED_MODEL = 'selected_model_id';
const KEY_IMAGE_MAX_SLICE = 'image_max_slice_nums';

// Slice cap bounds.  9 = MiniCPM-V upper bound (clip.cpp::get_best_grid).
// Out-of-the-box we default to the upper bound so first-launch image
// quality matches what the model card promises; users opt into faster
// prefill by dragging the chat-page slider down (1 = no slicing,
// ~9x fewer image tokens).  Mirrors LlamaEngine.kt.
export const MIN_IMAGE_SLICE = 1;
export const MAX_IMAGE_SLICE = 9;
export const DEFAULT_IMAGE_SLICE = MAX_IMAGE_SLICE;

export const MODEL_SUBDIR = 'models';
// Per-turn token budget. iOS demo (MTMDParams.swift) uses 100 because ANE
// makes generation fast enough that the cap is rarely hit; on Android +
// HarmonyOS with CPU-only inference users complained about replies getting
// truncated mid-sentence, so we raise it to a safer ceiling. 512 tokens is
// roughly 250-350 Chinese characters per turn, which covers the vast majority
// of single-turn answers; the n_ctx=4096 buffer plus shift_context() in
// llama_napi.cpp still keeps multi-turn chats stable.
export const DEFAULT_PREDICT_LENGTH = 512;
export const DEFAULT_SYSTEM_PROMPT =
  '你是一个有用且诚实的AI助手。当用户发送图片时，请仔细观察图片内容并准确回答用户的问题。';

export type StateListener = (s: LlamaState) => void;

// Single chunk from a streaming generation: `done=true` means the stream
// has ended; `value` is the textual token (UTF-8 already validated on the
// native side; never split mid-codepoint).
export interface TokenChunk {
  value: string;
  done: boolean;
}

// Streaming token sequence returned by sendUserPrompt. ArkTS strict mode
// disallows Symbol.asyncIterator, so we expose an explicit `next()` API:
//
//     const s = engine.sendUserPrompt('hello');
//     while (true) {
//       const c = await s.next();
//       if (c.done) break;
//       buf += c.value;
//     }
export interface TokenStream {
  cancel(): void;
  next(): Promise<TokenChunk>;
}

export class LlamaEngine {
  private static instance: LlamaEngine | null = null;

  private readonly context: common.Context;
  private readonly nativeLibDir: string;

  private state: LlamaState = LlamaState.Uninitialized;
  private listeners: StateListener[] = [];

  // Mirror of Dispatchers.IO.limitedParallelism(1): every native invocation
  // is appended to this promise so we never have two LLM calls in flight at
  // the same time.
  private chain: Promise<void> = Promise.resolve();

  private mmprojLoaded: boolean = false;
  private readyForSystemPrompt: boolean = false;

  private constructor(context: common.Context) {
    this.context = context;
    this.nativeLibDir = `${context.bundleCodeDir}/libs/arm64`;
  }

  static getInstance(context: common.Context): LlamaEngine {
    if (LlamaEngine.instance == null) {
      LlamaEngine.instance = new LlamaEngine(context);
      LlamaEngine.instance.initNative();
    }
    return LlamaEngine.instance;
  }

  // ------------------------------------------------------------------
  // State machine plumbing
  // ------------------------------------------------------------------

  getState(): LlamaState { return this.state; }

  isVisionSupported(): boolean { return this.mmprojLoaded; }

  addListener(l: StateListener): void {
    this.listeners.push(l);
    l(this.state);
  }

  removeListener(l: StateListener): void {
    const i = this.listeners.indexOf(l);
    if (i >= 0) this.listeners.splice(i, 1);
  }

  private setState(s: LlamaState): void {
    this.state = s;
    for (const l of this.listeners) {
      try { l(s); } catch (e) {
        hilog.error(DOMAIN, TAG, 'state listener threw: %{public}s', `${e}`);
      }
    }
  }

  // Append a native call to the serial chain, ensuring at-most-one-in-flight.
  private serial<T>(fn: () => Promise<T>): Promise<T> {
    let resolveT: (v: T) => void;
    let rejectT:  (e: object) => void;
    const out = new Promise<T>((res, rej) => { resolveT = res; rejectT = rej; });
    this.chain = this.chain.then(async () => {
      try {
        resolveT(await fn());
      } catch (e) {
        rejectT(e as object);
      }
    });
    return out;
  }

  // ------------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------------

  private initNative(): void {
    this.chain = this.chain.then(() => {
      if (this.state.name !== 'Uninitialized') {
        throw new Error(`Cannot init in state ${this.state.name}`);
      }
      this.setState(LlamaState.Initializing);
      hilog.info(DOMAIN, TAG, 'Loading native library...');
      try {
        nativeEngine.init(this.nativeLibDir);
        this.setState(LlamaState.Initialized);
        hilog.info(DOMAIN, TAG, 'Native library loaded! System info:\n%{public}s',
                   nativeEngine.systemInfo());
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'Failed to load native library: %{public}s', `${e}`);
        this.setState(LlamaState.error(`${e}`));
        throw new Error(`init native failed: ${e}`);
      }

      // Pre-create per-model directories so that `hdc file send` can side-load
      // GGUFs into the sandbox without touching the in-app downloader.
      // hdc's file transfer cannot create intermediate directories, but it
      // can write into a directory that already exists, so doing this once at
      // engine init makes development iterations massively faster.
      const modelsRoot = `${this.context.filesDir}/${MODEL_SUBDIR}`;
      try {
        if (!fs.accessSync(modelsRoot)) fs.mkdirSync(modelsRoot, true);
        for (const m of AVAILABLE_MODELS) {
          const dir = `${modelsRoot}/${m.id}`;
          if (!fs.accessSync(dir)) fs.mkdirSync(dir, true);
        }
        hilog.info(DOMAIN, TAG, 'Model dirs pre-created under %{public}s', modelsRoot);
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'Failed to pre-create model dirs: %{public}s', `${e}`);
      }
    });
  }

  loadModel(modelPath: string, mmprojPath: string | null = null): Promise<void> {
    return this.serial(async () => {
      if (this.state.name !== 'Initialized') {
        throw new Error(`Cannot load model in state ${this.state.name}`);
      }
      hilog.info(DOMAIN, TAG, 'Checking access to model file... \n%{public}s', modelPath);
      LlamaEngine.requireRegularFile(modelPath, 'model');

      hilog.info(DOMAIN, TAG, 'Loading model... \n%{public}s', modelPath);
      this.readyForSystemPrompt = false;
      this.setState(LlamaState.LoadingModel);

      const rc = nativeEngine.load(modelPath);
      if (rc !== 0) {
        const err = new Error(`Failed to load model (code: ${rc})`);
        this.setState(LlamaState.error(err.message));
        throw err;
      }

      if (mmprojPath != null) {
        hilog.info(DOMAIN, TAG, 'Checking access to mmproj... \n%{public}s', mmprojPath);
        LlamaEngine.requireRegularFile(mmprojPath, 'mmproj');
        const sliceCap = await LlamaEngine.getImageMaxSliceNums(this.context);
        hilog.info(DOMAIN, TAG, 'Loading mmproj (image_max_slice_nums=%{public}d)...', sliceCap);
        const mrc = nativeEngine.loadMmproj(mmprojPath, sliceCap);
        if (mrc !== 0) {
          hilog.warn(DOMAIN, TAG,
                     'Failed to load mmproj (code: %{public}d), continuing without vision', mrc);
        } else {
          this.mmprojLoaded = true;
          hilog.info(DOMAIN, TAG, 'mmproj loaded successfully!');
        }
      }

      const prc = nativeEngine.prepare();
      if (prc !== 0) {
        const err = new Error(`Failed to prepare resources (code: ${prc})`);
        this.setState(LlamaState.error(err.message));
        throw err;
      }
      hilog.info(DOMAIN, TAG, 'Model loaded!');
      this.readyForSystemPrompt = true;
      this.setState(LlamaState.ModelReady);
    });
  }

  setSystemPrompt(prompt: string): Promise<void> {
    return this.serial(() => {
      if (prompt.length === 0) {
        return Promise.reject(new Error('System prompt cannot be empty'));
      }
      if (!this.readyForSystemPrompt) {
        return Promise.reject(new Error('System prompt must be set right after load'));
      }
      if (this.state.name !== 'ModelReady') {
        return Promise.reject(new Error(`Cannot process system prompt in state ${this.state.name}`));
      }
      hilog.info(DOMAIN, TAG, 'Sending system prompt...');
      this.readyForSystemPrompt = false;
      this.setState(LlamaState.ProcessingSystemPrompt);

      const rc = nativeEngine.processSystemPrompt(prompt);
      if (rc !== 0) {
        const err = new Error(`Failed to process system prompt: ${rc}`);
        this.setState(LlamaState.error(err.message));
        return Promise.reject(err);
      }
      hilog.info(DOMAIN, TAG, 'System prompt processed!');
      this.setState(LlamaState.ModelReady);
      return Promise.resolve();
    });
  }

  prefillImage(imageData: ArrayBuffer): Promise<void> {
    return this.serial(() => {
      if (!this.mmprojLoaded) {
        return Promise.reject(new Error('Vision model not loaded'));
      }
      if (this.state.name !== 'ModelReady') {
        return Promise.reject(new Error(`Cannot prefill image in state ${this.state.name}`));
      }
      hilog.info(DOMAIN, TAG, 'Prefilling image (%{public}d bytes)...', imageData.byteLength);
      this.setState(LlamaState.PrefillingImage);

      const rc = nativeEngine.prefillImage(imageData);
      if (rc !== 0) {
        this.setState(LlamaState.ModelReady);
        return Promise.reject(new Error(`Failed to prefill image (code: ${rc})`));
      }
      hilog.info(DOMAIN, TAG, 'Image prefilled!');
      this.setState(LlamaState.ModelReady);
      return Promise.resolve();
    });
  }

  clearContext(): Promise<void> {
    return this.serial(() => {
      if (this.state.name !== 'ModelReady') {
        return Promise.reject(new Error(`Cannot clear context in state ${this.state.name}`));
      }
      nativeEngine.fullReset();
      this.readyForSystemPrompt = true;
      hilog.info(DOMAIN, TAG, 'Context fully reset - ready for new conversation');
      return Promise.resolve();
    });
  }

  // ------------------------------------------------------------------
  // sendUserPrompt: streaming generation. Returns an AsyncIterable<string>
  // backed by the native streamUserPrompt threadsafe-function callbacks.
  // ------------------------------------------------------------------

  sendUserPrompt(message: string,
                 predictLength: number = DEFAULT_PREDICT_LENGTH): TokenStream {
    if (message.length === 0) {
      throw new Error('User prompt must not be empty!');
    }
    if (this.state.name !== 'ModelReady') {
      throw new Error(`User prompt discarded due to: ${this.state.name}`);
    }

    const stream = new StreamImpl();

    const onToken = (t: string): void => stream.appendToken(t);
    const onDone = (wasCancelled: boolean): void => {
      this.readyForSystemPrompt = false;
      this.setState(LlamaState.ModelReady);
      hilog.info(DOMAIN, TAG, 'Generation done (cancelled=%{public}s)', `${wasCancelled}`);
      stream.finish(wasCancelled);
    };

    // Kick off serially so we don't race with another native call.
    this.serial(() => {
      hilog.info(DOMAIN, TAG, 'Sending user prompt...');
      this.readyForSystemPrompt = false;
      this.setState(LlamaState.ProcessingUserPrompt);
      const rc = nativeEngine.streamUserPrompt(message, predictLength, onToken, onDone);
      if (rc !== 0) {
        const err = new Error(`streamUserPrompt failed to start: ${rc}`);
        this.setState(LlamaState.error(err.message));
        stream.fail(err);
      } else {
        // The state immediately moves to Generating; the prefill step inside
        // the worker thread is brief and we don't surface a separate state
        // for it (mirrors Android demo's UX).
        this.setState(LlamaState.Generating);
      }
      return Promise.resolve();
    }).catch((e: Error) => {
      stream.fail(e);
    });

    return stream;
  }

  cancelGeneration(): void {
    nativeEngine.cancelGeneration();
  }

  unloadModel(): Promise<void> {
    return this.serial(() => {
      if (this.state.name === 'ModelReady') {
        hilog.info(DOMAIN, TAG, 'Unloading model...');
        this.readyForSystemPrompt = false;
        this.mmprojLoaded = false;
        this.setState(LlamaState.UnloadingModel);
        nativeEngine.unload();
        this.setState(LlamaState.Initialized);
        hilog.info(DOMAIN, TAG, 'Model unloaded');
      }
      return Promise.resolve();
    });
  }

  resetToInitialized(): void {
    this.mmprojLoaded = false;
    this.readyForSystemPrompt = false;
    this.setState(LlamaState.Initialized);
  }

  destroy(): void {
    this.chain = this.chain.then(() => {
      this.readyForSystemPrompt = false;
      this.mmprojLoaded = false;
      switch (this.state.name) {
        case 'Uninitialized':
          break;
        case 'Initialized':
          nativeEngine.shutdown();
          break;
        default:
          nativeEngine.unload();
          nativeEngine.shutdown();
          break;
      }
    });
  }

  // ------------------------------------------------------------------
  // Storage layout (mirrors the Android companion-object helpers)
  // ------------------------------------------------------------------

  static modelDir(context: common.Context): string {
    return `${context.filesDir}/${MODEL_SUBDIR}`;
  }

  static modelDirFor(context: common.Context, model: ModelInfo): string {
    return `${LlamaEngine.modelDir(context)}/${model.id}`;
  }

  static modelPath(context: common.Context): string {
    const m = LlamaEngine.getSelectedModel(context);
    return `${LlamaEngine.modelDirFor(context, m)}/${m.ggufFileName}`;
  }

  static mmprojPath(context: common.Context): string {
    const m = LlamaEngine.getSelectedModel(context);
    return `${LlamaEngine.modelDirFor(context, m)}/${m.mmprojFileName}`;
  }

  static modelsExist(context: common.Context): boolean {
    return fs.accessSync(LlamaEngine.modelPath(context)) &&
           fs.accessSync(LlamaEngine.mmprojPath(context));
  }

  // SharedPreferences-style selected-model persistence. The preferences API
  // is async on HarmonyOS, so we cache the value in memory after first read
  // and write through synchronously after that.
  private static cachedSelectedId: string | null = null;
  private static cachedPrefs: dataPreferences.Preferences | null = null;

  private static prefs(context: common.Context): Promise<dataPreferences.Preferences> {
    if (LlamaEngine.cachedPrefs) {
      return Promise.resolve(LlamaEngine.cachedPrefs);
    }
    return new Promise<dataPreferences.Preferences>((resolve, reject) => {
      dataPreferences.getPreferences(context, PREFS_NAME, (err: BusinessError, p: dataPreferences.Preferences) => {
        if (err) { reject(err); return; }
        LlamaEngine.cachedPrefs = p;
        resolve(p);
      });
    });
  }

  static getSelectedModel(context: common.Context): ModelInfo {
    if (LlamaEngine.cachedSelectedId == null) {
      // Best-effort sync read: use whatever's been cached, fall back to default.
      LlamaEngine.warmSelectedId(context);
      return DEFAULT_MODEL;
    }
    return findModelById(LlamaEngine.cachedSelectedId);
  }

  // Async warmup so the next sync getSelectedModel returns the persisted value.
  static async warmSelectedId(context: common.Context): Promise<void> {
    try {
      const p = await LlamaEngine.prefs(context);
      const id = await p.get(KEY_SELECTED_MODEL, DEFAULT_MODEL.id) as string;
      LlamaEngine.cachedSelectedId = id;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'warmSelectedId failed: %{public}s', `${e}`);
      LlamaEngine.cachedSelectedId = DEFAULT_MODEL.id;
    }
  }

  static async setSelectedModel(context: common.Context, modelId: string): Promise<void> {
    LlamaEngine.cachedSelectedId = modelId;
    const p = await LlamaEngine.prefs(context);
    await p.put(KEY_SELECTED_MODEL, modelId);
    await p.flush();
  }

  // Slice cap (1..9) is persisted globally (not per-model) - users keep
  // their preferred speed / quality trade-off across model swaps and all
  // MiniCPM-V variants share the slicing semantics.  Mirrors LlamaEngine.kt.
  private static cachedImageMaxSlice: number | null = null;

  static async getImageMaxSliceNums(context: common.Context): Promise<number> {
    if (LlamaEngine.cachedImageMaxSlice != null) {
      return LlamaEngine.cachedImageMaxSlice;
    }
    try {
      const p = await LlamaEngine.prefs(context);
      const v = await p.get(KEY_IMAGE_MAX_SLICE, DEFAULT_IMAGE_SLICE) as number;
      const clamped = Math.max(MIN_IMAGE_SLICE, Math.min(MAX_IMAGE_SLICE, v));
      LlamaEngine.cachedImageMaxSlice = clamped;
      return clamped;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'getImageMaxSliceNums failed: %{public}s', `${e}`);
      LlamaEngine.cachedImageMaxSlice = DEFAULT_IMAGE_SLICE;
      return DEFAULT_IMAGE_SLICE;
    }
  }

  // Best-effort sync getter (returns last cached value, or default if the
  // cache hasn't been warmed yet).  Useful for initial UI rendering before
  // the async preferences read finishes.
  static getImageMaxSliceNumsCached(): number {
    return LlamaEngine.cachedImageMaxSlice ?? DEFAULT_IMAGE_SLICE;
  }

  static async setImageMaxSliceNumsPref(context: common.Context, n: number): Promise<void> {
    const clamped = Math.max(MIN_IMAGE_SLICE, Math.min(MAX_IMAGE_SLICE, n));
    LlamaEngine.cachedImageMaxSlice = clamped;
    const p = await LlamaEngine.prefs(context);
    await p.put(KEY_IMAGE_MAX_SLICE, clamped);
    await p.flush();
  }

  // Live update of the slice cap.  Persists the new value AND patches the
  // in-memory clip context so the next image picked uses the new cap
  // immediately - no mmproj reload required.  Cheap (no allocation, no
  // warmup): safe to wire to a continuous slider.
  async updateImageMaxSliceNums(n: number): Promise<void> {
    const clamped = Math.max(MIN_IMAGE_SLICE, Math.min(MAX_IMAGE_SLICE, n));
    await LlamaEngine.setImageMaxSliceNumsPref(this.context, clamped);
    if (this.mmprojLoaded) {
      hilog.info(DOMAIN, TAG, 'Live-updating image_max_slice_nums = %{public}d', clamped);
      nativeEngine.setImageMaxSliceNums(clamped);
    } else {
      hilog.info(DOMAIN, TAG,
                 'image_max_slice_nums = %{public}d persisted; will apply on next mmproj load',
                 clamped);
    }
  }

  // ------------------------------------------------------------------
  // Legacy layout / filename migration (mirrors Android demo)
  // ------------------------------------------------------------------

  static migrateLegacyLayoutIfNeeded(context: common.Context): void {
    const root = LlamaEngine.modelDir(context);
    if (!fs.accessSync(root)) return;

    for (const model of AVAILABLE_MODELS) {
      const targetDir = LlamaEngine.modelDirFor(context, model);
      const flatGguf  = `${root}/${model.ggufFileName}`;
      const flatMmproj = `${root}/${model.mmprojFileName}`;

      if (fs.accessSync(flatGguf) || fs.accessSync(flatMmproj)) {
        if (!fs.accessSync(targetDir)) fs.mkdirSync(targetDir, true);
        if (fs.accessSync(flatGguf)) {
          const dst = `${targetDir}/${model.ggufFileName}`;
          if (!fs.accessSync(dst)) {
            try { fs.renameSync(flatGguf, dst); }
            catch (e) {
              hilog.warn(DOMAIN, TAG, 'migrate %{public}s failed: %{public}s', model.ggufFileName, `${e}`);
            }
          }
        }
        if (fs.accessSync(flatMmproj)) {
          const dst = `${targetDir}/${model.mmprojFileName}`;
          if (!fs.accessSync(dst)) {
            try { fs.renameSync(flatMmproj, dst); }
            catch (e) {
              hilog.warn(DOMAIN, TAG, 'migrate %{public}s failed: %{public}s', model.mmprojFileName, `${e}`);
            }
          }
        }
      }

      const renames = LEGACY_FILE_RENAMES[model.id];
      if (renames) {
        const perModelDir = `${root}/${model.id}`;
        if (!fs.accessSync(perModelDir)) continue;
        for (const r of renames) {
          const src = `${perModelDir}/${r.oldName}`;
          const dst = `${perModelDir}/${r.newName}`;
          if (fs.accessSync(src) && !fs.accessSync(dst)) {
            try { fs.renameSync(src, dst); }
            catch (e) {
              hilog.warn(DOMAIN, TAG, 'rename %{public}s -> %{public}s failed: %{public}s',
                         r.oldName, r.newName, `${e}`);
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------------
  // Download wrapper (delegates to DownloadManager so the engine stays small)
  // ------------------------------------------------------------------

  static downloadModels(context: common.Context, onProgress: ProgressListener): Promise<void> {
    return downloadModelsForSelected(context, onProgress);
  }

  // ------------------------------------------------------------------
  // Internal helpers
  // ------------------------------------------------------------------

  private static requireRegularFile(path: string, label: string): void {
    if (!fs.accessSync(path)) {
      throw new Error(`${label} file not found: ${path}`);
    }
    const stat = fs.statSync(path);
    if (!stat.isFile()) {
      throw new Error(`${label} is not a regular file: ${path}`);
    }
  }
}

// Concrete TokenStream implementation. ArkTS strict mode forbids object
// literals with methods, so we use an explicit class. Native callbacks
// (`onToken` / `onDone` / `fail`) push tokens into the queue and wake any
// pending `next()` waiter.
type TokenWaiter = (v: TokenChunk) => void;

class StreamImpl implements TokenStream {
  private queue: string[] = [];
  private waiters: TokenWaiter[] = [];
  private finished: boolean = false;
  private cancelled: boolean = false;
  private error: Error | null = null;

  appendToken(t: string): void {
    if (t.length > 0) {
      this.queue.push(t);
    }
    this.drain();
  }

  finish(wasCancelled: boolean): void {
    this.cancelled = wasCancelled;
    this.finished = true;
    this.drain();
  }

  fail(e: Error): void {
    this.error = e;
    this.finished = true;
    this.drain();
  }

  cancel(): void {
    if (!this.finished) {
      nativeEngine.cancelGeneration();
    }
  }

  next(): Promise<TokenChunk> {
    if (this.error !== null) {
      return Promise.reject(this.error);
    }
    if (this.queue.length > 0) {
      const chunk: TokenChunk = { value: this.queue.shift()!, done: false };
      return Promise.resolve(chunk);
    }
    if (this.finished) {
      const chunk: TokenChunk = { value: '', done: true };
      return Promise.resolve(chunk);
    }
    return new Promise<TokenChunk>((res: TokenWaiter): void => { this.waiters.push(res); });
  }

  private drain(): void {
    while (this.waiters.length > 0 && (this.queue.length > 0 || this.finished)) {
      const resolve: TokenWaiter = this.waiters.shift()!;
      if (this.queue.length > 0) {
        const chunk: TokenChunk = { value: this.queue.shift()!, done: false };
        resolve(chunk);
      } else {
        const chunk: TokenChunk = { value: '', done: true };
        resolve(chunk);
      }
    }
  }
}
