// Direct translation of the `sealed class LlamaState` from
// MiniCPM-V-demo-Android/app/src/main/java/com/example/minicpm_v_demo/LlamaEngine.kt.
// ArkTS has no sealed classes; we use a string discriminator that any
// component can switch on, plus an attached error payload.

export type LlamaStateName =
  | 'Uninitialized'
  | 'Initializing'
  | 'Initialized'
  | 'LoadingModel'
  | 'ModelReady'
  | 'ProcessingSystemPrompt'
  | 'PrefillingImage'
  | 'ProcessingUserPrompt'
  | 'Generating'
  | 'UnloadingModel'
  | 'Error';

export class LlamaState {
  readonly name: LlamaStateName;
  readonly errorMessage: string | null;

  private constructor(name: LlamaStateName, errorMessage: string | null = null) {
    this.name = name;
    this.errorMessage = errorMessage;
  }

  static readonly Uninitialized           = new LlamaState('Uninitialized');
  static readonly Initializing            = new LlamaState('Initializing');
  static readonly Initialized             = new LlamaState('Initialized');
  static readonly LoadingModel            = new LlamaState('LoadingModel');
  static readonly ModelReady              = new LlamaState('ModelReady');
  static readonly ProcessingSystemPrompt  = new LlamaState('ProcessingSystemPrompt');
  static readonly PrefillingImage         = new LlamaState('PrefillingImage');
  static readonly ProcessingUserPrompt    = new LlamaState('ProcessingUserPrompt');
  static readonly Generating              = new LlamaState('Generating');
  static readonly UnloadingModel          = new LlamaState('UnloadingModel');

  static error(message: string): LlamaState {
    return new LlamaState('Error', message);
  }
}
