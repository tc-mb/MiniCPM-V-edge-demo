// Direct port of MiniCPM-V-demo-Android/.../ModelInfo.kt.
//
// Two download strategies, in priority order:
//
//  1. Direct URL (directGgufUrl / directMmprojUrl) — used as-is. This is how
//     the iOS demo handles MiniCPM-V-4.6 today: GGUFs are not yet on
//     HuggingFace, so a temporary OBS link is used during the TestFlight
//     period. Whenever both direct URLs are non-null, HF/MS are skipped
//     entirely.
//
//  2. HuggingFace + ModelScope fallback (hfRepo / msRepo) — the standard path
//     for already-published models such as MiniCPM-V-4. The downloader probes
//     HF first and falls back to ModelScope on failure.
//
// When ggufMd5 / mmprojMd5 are provided, the downloader verifies the
// downloaded file's MD5 and deletes + raises on mismatch. Mirrors the iOS
// demo's MBV4ModelDownloadManager / MBV46ModelDownloadManager behaviour.

export class ModelInfo {
  readonly id: string;
  readonly displayName: string;
  readonly description: string;
  readonly ggufFileName: string;
  readonly mmprojFileName: string;
  readonly hfRepo: string | null;
  readonly msRepo: string | null;
  readonly hfBranch: string;
  readonly msBranch: string;
  readonly directGgufUrl: string | null;
  readonly directMmprojUrl: string | null;
  readonly ggufMd5: string | null;
  readonly mmprojMd5: string | null;

  constructor(
    id: string,
    displayName: string,
    description: string,
    ggufFileName: string,
    mmprojFileName: string,
    hfRepo: string | null = null,
    msRepo: string | null = null,
    hfBranch: string = 'main',
    msBranch: string = 'master',
    directGgufUrl: string | null = null,
    directMmprojUrl: string | null = null,
    ggufMd5: string | null = null,
    mmprojMd5: string | null = null
  ) {
    this.id = id;
    this.displayName = displayName;
    this.description = description;
    this.ggufFileName = ggufFileName;
    this.mmprojFileName = mmprojFileName;
    this.hfRepo = hfRepo;
    this.msRepo = msRepo;
    this.hfBranch = hfBranch;
    this.msBranch = msBranch;
    this.directGgufUrl = directGgufUrl;
    this.directMmprojUrl = directMmprojUrl;
    this.ggufMd5 = ggufMd5;
    this.mmprojMd5 = mmprojMd5;
  }

  hasDirectUrls(): boolean {
    return !!this.directGgufUrl && !!this.directMmprojUrl;
  }
}

// Direct URL base for the V-4.6 release GGUFs hosted on Huawei Cloud OBS.
// MUST match MiniCPMModelConst.swift on iOS and ModelInfo.kt on Android so
// all three demos pull the exact same bytes.
const V46_OBS_BASE =
  'https://data-transfer-huawei.obs.cn-north-4.myhuaweicloud.com/minicpmv46-instruct';

export const AVAILABLE_MODELS: ModelInfo[] = [
  new ModelInfo(
    'minicpm-v-4',
    'MiniCPM-V-4 (Q4_K_M)',
    '轻量级多模态模型，支持图文理解 (4.1B)',
    'ggml-model-Q4_K_M.gguf',
    'mmproj-model-f16.gguf',
    'openbmb/MiniCPM-V-4-gguf',
    'OpenBMB/MiniCPM-V-4-gguf'
    // No MD5 here on purpose: HF / ModelScope serve via git-LFS which already
    // provides hash-based integrity checks. The iOS demo's MD5 (8fc4cc88...)
    // refers to ggml-model-Q4_0.gguf, a different quant from the Q4_K_M used
    // here.
  ),
  // MiniCPM-V-4.6 (release / instruct): direct OBS link, identical to iOS /
  // Android. File names follow the upstream HF naming for the released
  // GGUFs. ID kept as "minicpm-v-4_6-instruct" so the per-model subdirectory
  // layout is unchanged from previous demo builds; LEGACY_FILE_RENAMES handles
  // the old filenames.
  new ModelInfo(
    'minicpm-v-4_6-instruct',
    'MiniCPM-V-4.6 (Q4_K_M)',
    '新一代多模态模型，支持图文理解 (1.2B)',
    'MiniCPM-V-4_6-Q4_K_M.gguf',
    'mmproj-model-f16.gguf',
    null,
    null,
    'main',
    'master',
    `${V46_OBS_BASE}/MiniCPM-V-4_6-Q4_K_M.gguf`,
    `${V46_OBS_BASE}/mmproj-model-f16.gguf`,
    'fd778481dd56b6036dd8f9cf7c1519cf',
    // mmproj is converted on the Support-iOS-Demo branch (writes
    // clip.projector_type=merger, which the demo's clip.cpp accepts);
    // the upstream-branch conversion would write minicpmv4_6 and fail to load.
    'aad0d36e43a35412d72ed27a1248c7ef'
  ),
];

export const DEFAULT_MODEL: ModelInfo = AVAILABLE_MODELS[0];

// Maps any historical filename (left) to the current canonical name (right)
// for files that may already exist in a user's per-model subdirectory.
// Each entry is consulted on app start; if a left-hand file is found it is
// renamed to the right-hand one. MD5 checks then either accept it or trigger
// a re-download. Keep in sync with ModelInfo.kt LEGACY_FILE_RENAMES.
export interface LegacyRename {
  oldName: string;
  newName: string;
}

export const LEGACY_FILE_RENAMES: Record<string, LegacyRename[]> = {
  'minicpm-v-4_6-instruct': [
    { oldName: 'MiniCPM-V4.6-instruct-Q4_K_M.gguf', newName: 'MiniCPM-V-4_6-Q4_K_M.gguf' },
    { oldName: 'minicpmv46-llm-Q4_K_M.gguf',         newName: 'MiniCPM-V-4_6-Q4_K_M.gguf' },
    { oldName: 'mmproj-v46-model-f16.gguf',          newName: 'mmproj-model-f16.gguf'    },
  ],
};

export function findModelById(id: string): ModelInfo {
  for (const m of AVAILABLE_MODELS) {
    if (m.id === id) {
      return m;
    }
  }
  return DEFAULT_MODEL;
}
