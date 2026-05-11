// Type declarations for `libentry.so`. Mirror the function names registered in
// napi_init.cpp (RegisterModule). When you add a new NAPI binding remember to
// keep all four sites in sync:
//   * llama_napi.cpp     (definition)
//   * napi_init.cpp      (property descriptor)
//   * Index.d.ts         (this file)
//   * LlamaEngine.ets    (caller)

export const init: (nativeLibDir: string) => void;
export const load: (modelPath: string) => number;
// imageMaxSliceNums: 1..9 inclusive (or -1 for the model default).  See
// llama_napi.cpp::LoadMmproj for semantics.  Persisted by the chat-page
// slider; defaults to 9 (MiniCPM-V upper bound, best detail) on first
// launch.  Drag the slider down to 1 for single-overview / fastest.
export const loadMmproj: (mmprojPath: string, imageMaxSliceNums: number) => number;
// Live override of the slice cap.  No mmproj reload required - takes
// effect from the next image encode onwards.
export const setImageMaxSliceNums: (n: number) => void;
export const prepare: () => number;
export const systemInfo: () => string;
export const processSystemPrompt: (prompt: string) => number;

// streamUserPrompt folds processUserPrompt + while(generateNextToken) into one
// async API. Returns 0 on a successfully *started* stream; non-zero indicates
// the stream could not start (e.g. another stream is already in flight).
// onToken fires for each UTF-8 valid token chunk on the JS thread.
// onDone(cancelled) fires exactly once at the end on the JS thread.
export const streamUserPrompt: (
  prompt: string,
  predictLength: number,
  onToken: (token: string) => void,
  onDone: (cancelled: boolean) => void
) => number;

// prefillImage runs ViT + perceiver + llama_decode for the image - heavy
// work (10-30 s at image_max_slice_nums=9 on a phone-class CPU).  It is
// dispatched onto a libuv worker thread internally so the JS main thread
// stays responsive.  Resolves to 0 on success, rejects with a non-zero
// rc otherwise (1=mmproj missing, 2=bad ArrayBuffer, 3=bitmap decode
// failure, 4=mtmd_tokenize failure, 5=mtmd_helper_eval_chunks failure,
// 6/7=async work setup failure).
export const prefillImage: (data: ArrayBuffer) => Promise<number>;
export const fullReset: () => void;
export const cancelGeneration: () => void;
export const unload: () => void;
export const shutdown: () => void;
