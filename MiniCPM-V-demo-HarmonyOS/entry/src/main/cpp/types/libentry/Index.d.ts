// Type declarations for `libentry.so`. Mirror the function names registered in
// napi_init.cpp (RegisterModule). When you add a new NAPI binding remember to
// keep all four sites in sync:
//   * llama_napi.cpp     (definition)
//   * napi_init.cpp      (property descriptor)
//   * Index.d.ts         (this file)
//   * LlamaEngine.ets    (caller)

export const init: (nativeLibDir: string) => void;
export const load: (modelPath: string) => number;
export const loadMmproj: (mmprojPath: string) => number;
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

export const prefillImage: (data: ArrayBuffer) => number;
export const fullReset: () => void;
export const cancelGeneration: () => void;
export const unload: () => void;
export const shutdown: () => void;
